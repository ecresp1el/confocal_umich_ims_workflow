#!/usr/bin/env python3
"""Create conservative, visualization-only previews for prepared confocal Z-stacks.

Examples
--------
python scripts/beautify_zstacks.py --root /Volumes/MannySSD/ForNeuronRebuttal_10122026/BiVe3 \
  --sample 173-4 --preview-only
python scripts/beautify_zstacks.py --root /Volumes/MannySSD/ForNeuronRebuttal_10122026/BiVe4 \
  --sample 166-4 --preview-only

The script reads only ``*_prepared_zstack.tif`` and never changes source files.
Its PNG outputs are explicitly visualization previews, not quantitative data.
"""

from __future__ import annotations

import argparse
import csv
import json
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path

import matplotlib
import numpy as np
import tifffile
from scipy.ndimage import uniform_filter
from skimage import exposure, restoration

matplotlib.use("Agg")
from matplotlib import pyplot as plt


@dataclass(frozen=True)
class PreviewSettings:
    display_low_percentile: float = 1.0
    display_high_percentile: float = 99.8
    adjacent_plane_weight: float = 0.20
    representative_plane_weight: float = 0.60
    tv_weight: float = 0.001
    background_window_px: int = 101
    background_suppression_fraction: float = 0.55
    clahe_kernel_px: int = 256
    clahe_clip_limit: float = 0.002
    fixed_planes_zero_indexed: tuple[int, int, int] = (2, 3, 4)


@dataclass(frozen=True)
class SampleFiles:
    analysis_dir: Path
    stack_path: Path
    channel_map_path: Path
    settings_path: Path
    output_dir: Path


class SampleDiscovery:
    """Find one Fiji analysis directory and validate its target channels."""

    def __init__(self, root: Path, sample_text: str, output_folder: str) -> None:
        self.root = root
        self.sample_text = sample_text.lower()
        self.output_folder = output_folder

    def find(self) -> SampleFiles:
        candidates = sorted(
            directory
            for directory in self.root.glob("*_FijiAnalysis")
            if not directory.name.startswith("._") and self.sample_text in directory.name.lower()
        )
        if len(candidates) != 1:
            raise ValueError(
                f"Expected exactly one '*_FijiAnalysis' folder matching {self.sample_text!r}; "
                f"found {len(candidates)}. Use a more specific --sample value."
            )
        analysis_dir = candidates[0]
        stacks = [path for path in (analysis_dir / "01_prepared_zstack").glob("*_prepared_zstack.tif") if not path.name.startswith("._")]
        maps = [path for path in (analysis_dir / "00_import_and_channels").glob("*_channel_map.csv") if not path.name.startswith("._")]
        settings = [path for path in (analysis_dir / "01_prepared_zstack").glob("*_zstack_settings.txt") if not path.name.startswith("._")]
        if len(stacks) != 1 or len(maps) != 1 or len(settings) != 1:
            raise FileNotFoundError("Prepared stack, channel map, or Z-stack settings file is missing or ambiguous.")
        return SampleFiles(
            analysis_dir=analysis_dir,
            stack_path=stacks[0],
            channel_map_path=maps[0],
            settings_path=settings[0],
            output_dir=analysis_dir / self.output_folder / "previews",
        )

    def channel_map(self, path: Path) -> dict[int, str]:
        with path.open(newline="") as handle:
            rows = csv.DictReader(handle)
            mapping = {int(row["channel_index"]): row["user_marker"].strip() for row in rows}
        if not any("pv" in marker.lower() for marker in mapping.values()):
            raise ValueError(f"Channel map must identify PV; got {mapping}.")
        return mapping


class ChannelPreviewer:
    """Refine a fixed, aligned three-plane blend independently for one channel."""

    def __init__(self, stack_path: Path, channel_index: int, settings: PreviewSettings) -> None:
        self.stack_path = stack_path
        self.channel_index = channel_index
        self.settings = settings

    def render(self) -> tuple[np.ndarray, np.ndarray, dict[str, object]]:
        with tifffile.TiffFile(self.stack_path) as tif:
            series = tif.series[0]
            if series.axes != "ZCYX" or len(series.shape) != 4:
                raise ValueError(f"Expected unambiguous ZCYX stack; found axes={series.axes}, shape={series.shape}.")
            z_count, channel_count, height, width = series.shape
            if not 0 <= self.channel_index < channel_count:
                raise ValueError(f"Channel index {self.channel_index + 1} is outside 1..{channel_count}.")
            imagej = tif.imagej_metadata or {}
            spacing = imagej.get("spacing")
            x_resolution = tif.pages[0].tags.get("XResolution")
            stack = tifffile.memmap(self.stack_path, series=0)
            before_z, representative_z, after_z = self.settings.fixed_planes_zero_indexed
            if before_z < 0 or after_z >= z_count:
                raise ValueError(f"Fixed Z planes {self.settings.fixed_planes_zero_indexed} exceed stack with {z_count} planes.")
            representative_raw_plane = np.array(stack[representative_z, self.channel_index], copy=True)
            adjacent_before = stack[before_z, self.channel_index].astype(np.float32)
            adjacent_after = stack[after_z, self.channel_index].astype(np.float32)
            depth_weighted = (
                self.settings.adjacent_plane_weight * adjacent_before
                + self.settings.representative_plane_weight * representative_raw_plane.astype(np.float32)
                + self.settings.adjacent_plane_weight * adjacent_after
            )
            normalized = depth_weighted / np.iinfo(np.uint16).max
            denoised = restoration.denoise_tv_chambolle(
                normalized, weight=self.settings.tv_weight, max_num_iter=20, eps=0.0002, channel_axis=None
            ).astype(np.float32, copy=False)
            background = uniform_filter(denoised, size=self.settings.background_window_px, output=np.float32)
            background_suppressed = (1.0 - self.settings.background_suppression_fraction) * denoised + self.settings.background_suppression_fraction * np.maximum(denoised - background, 0.0)
            padding = self.settings.clahe_kernel_px // 2
            padded = np.pad(background_suppressed, padding, mode="reflect")
            refined_padded = exposure.equalize_adapthist(
                padded, kernel_size=self.settings.clahe_kernel_px, clip_limit=self.settings.clahe_clip_limit
            ).astype(np.float32, copy=False)
            refined_normalized = refined_padded[padding:-padding, padding:-padding]
            metadata = {
                "axes": series.axes,
                "shape": list(series.shape),
                "dtype": str(series.dtype),
                "z_planes": z_count,
                "channel_count": channel_count,
                "z_spacing_um": spacing,
                "x_resolution_pixels_per_um": list(x_resolution.value) if x_resolution else None,
                "projection_method": "fixed aligned three-plane weighted blend followed by mild TV denoise, partial broad-background suppression, and conservative CLAHE",
                "representative_raw_z_plane_zero_indexed": representative_z,
                "depth_weights": [self.settings.adjacent_plane_weight, self.settings.representative_plane_weight, self.settings.adjacent_plane_weight],
                "planes_zero_indexed": list(self.settings.fixed_planes_zero_indexed),
                "visualization_only": "No size- or brightness-based component removal was applied.",
                "clahe_boundary_handling": "Reflect-padding for local contrast only; returned image retains the complete original XY field.",
            }
        return depth_weighted, refined_normalized, metadata


class ProcessingRun:
    """Coordinate conservative preview generation for PV and dTomato only."""

    def __init__(self, arguments: argparse.Namespace) -> None:
        self.arguments = arguments
        center_zero_indexed = arguments.center_z - 1
        self.settings = PreviewSettings(
            fixed_planes_zero_indexed=(center_zero_indexed - 1, center_zero_indexed, center_zero_indexed + 1),
            background_suppression_fraction=arguments.background_suppression,
        )

    @classmethod
    def from_command_line(cls) -> "ProcessingRun":
        parser = argparse.ArgumentParser(description=__doc__)
        parser.add_argument("--root", type=Path, required=True, help="BiVe3 input folder")
        parser.add_argument("--sample", required=True, help="Unique portion of one sample folder name")
        parser.add_argument("--center-z", type=int, default=4, help="One-indexed center plane for the three-plane blend")
        parser.add_argument(
            "--background-suppression",
            type=float,
            default=0.55,
            help="Fraction (0 to 1) of the broad background removed; default 0.55.",
        )
        parser.add_argument("--preview-only", action="store_true", help="Accepted for explicit preview-only runs")
        parser.add_argument("--output-folder", default="03_python_beautification")
        arguments = parser.parse_args()
        if not 0.0 <= arguments.background_suppression <= 1.0:
            parser.error("--background-suppression must be between 0 and 1.")
        return cls(arguments)

    def display_limits(self, images: tuple[np.ndarray, ...]) -> tuple[float, float]:
        sampled = np.concatenate([image[::16, ::16].ravel() for image in images])
        positive = sampled[sampled > 0]
        if positive.size == 0:
            return 0.0, 1.0
        low, high = np.percentile(positive, [self.settings.display_low_percentile, self.settings.display_high_percentile])
        return float(low), float(high if high > low else low + 1.0)

    def channel_rgb(self, image: np.ndarray, limits: tuple[float, float], color: tuple[float, float, float]) -> np.ndarray:
        normalized = np.clip((image - limits[0]) / (limits[1] - limits[0]), 0.0, 1.0)
        return normalized[..., None] * np.asarray(color, dtype=np.float32)

    def write_comparison(self, channels: dict[str, tuple[np.ndarray, np.ndarray, tuple[float, float]]], d_tomato_label: str, output_path: Path) -> None:
        colors = {"DAPI": (0.00, 0.00, 1.00), "PV": (0.00, 1.00, 0.00), "dTomato": (1.00, 0.00, 0.00)}
        titles = ("DAPI (Blue)", "PV (Green)", f"{d_tomato_label} (Red)", f"DAPI + PV + {d_tomato_label} merge", f"PV + {d_tomato_label} overlay")
        figure, axes = plt.subplots(2, 5, figsize=(25, 10), constrained_layout=True)
        for row_index in range(2):
            merge = np.zeros((*channels["PV"][0].shape, 3), dtype=np.float32)
            for column_index, marker in enumerate(("DAPI", "PV", "dTomato")):
                raw, enhanced, limits = channels[marker]
                image = raw if row_index == 0 else enhanced
                rgb = self.channel_rgb(image, limits, colors[marker])
                axes[row_index, column_index].imshow(rgb, interpolation="nearest")
                axes[row_index, column_index].set_title(titles[column_index], fontsize=12)
                axes[row_index, column_index].axis("off")
                merge += rgb
            axes[row_index, 3].imshow(np.clip(merge, 0.0, 1.0), interpolation="nearest")
            axes[row_index, 3].set_title(titles[3], fontsize=12)
            axes[row_index, 3].axis("off")
            pv_bive_merge = self.channel_rgb(channels["PV"][0] if row_index == 0 else channels["PV"][1], channels["PV"][2], colors["PV"])
            pv_bive_merge += self.channel_rgb(channels["dTomato"][0] if row_index == 0 else channels["dTomato"][1], channels["dTomato"][2], colors["dTomato"])
            axes[row_index, 4].imshow(np.clip(pv_bive_merge, 0.0, 1.0), interpolation="nearest")
            axes[row_index, 4].set_title(titles[4], fontsize=12)
            axes[row_index, 4].axis("off")
        figure.text(0.006, 0.70, "Before: raw", fontsize=14, rotation=90, va="center")
        figure.text(0.006, 0.30, "After: refined", fontsize=14, rotation=90, va="center")
        figure.suptitle("Three-plane aligned visualization comparison: raw versus independently refined channels", fontsize=16)
        figure.savefig(output_path, dpi=180, facecolor="white")
        plt.close(figure)

    def run(self) -> None:
        files = SampleDiscovery(self.arguments.root, self.arguments.sample, self.arguments.output_folder).find()
        channel_map = SampleDiscovery(self.arguments.root, self.arguments.sample, self.arguments.output_folder).channel_map(files.channel_map_path)
        targets: dict[str, tuple[int, str]] = {}
        for index, marker in channel_map.items():
            lowered = marker.lower()
            if lowered == "dapi":
                targets["DAPI"] = (index - 1, marker)
            elif "pv" in lowered:
                targets["PV"] = (index - 1, marker)
            elif "dtom" in lowered:
                targets["dTomato"] = (index - 1, marker)
        if set(targets) != {"DAPI", "PV", "dTomato"}:
            raise ValueError(f"Expected DAPI, PV, and dTomato channels; found {targets}.")
        files.output_dir.mkdir(parents=True, exist_ok=True)
        refined_dir = files.output_dir.parent / "refined"
        refined_dir.mkdir(parents=True, exist_ok=True)
        center_label = f"z{self.arguments.center_z}"
        report: dict[str, object] = {
            "created_utc": datetime.now(timezone.utc).isoformat(),
            "visualization_only": True,
            "input_stack": str(files.stack_path),
            "channel_map": channel_map,
            "parameters": asdict(self.settings),
            "outputs": {},
        }
        rendered_channels: dict[str, tuple[np.ndarray, np.ndarray, tuple[float, float]]] = {}
        for role, (channel_index, marker) in targets.items():
            depth_weighted, refined_normalized, metadata = ChannelPreviewer(files.stack_path, channel_index, self.settings).render()
            safe_marker = marker.replace("/", "_").replace(" ", "_")
            limits = self.display_limits((depth_weighted,))
            refined_limits = self.display_limits((refined_normalized,))
            refined_display = np.clip((refined_normalized - refined_limits[0]) / (refined_limits[1] - refined_limits[0]), 0.0, 1.0)
            refined_display = refined_display * (limits[1] - limits[0]) + limits[0]
            refined_tiff_path = refined_dir / f"{files.analysis_dir.name}_{safe_marker}_{center_label}_three_plane_refined_visualization.tif"
            tifffile.imwrite(
                refined_tiff_path,
                np.clip(refined_display, 0, np.iinfo(np.uint16).max).astype(np.uint16),
                metadata={"axes": "YX"},
                description="Visualization-only channel refinement; not for quantification.",
            )
            rendered_channels[role] = (depth_weighted, refined_display, limits)
            report["outputs"][marker] = {
                "refined_full_resolution_tiff": str(refined_tiff_path),
                "shared_display_limits": list(limits),
                "refined_display_percentile_limits": list(refined_limits),
                "metadata": metadata,
            }
        d_tomato_label = targets["dTomato"][1].replace("dtom", "-dTomato")
        comparison_path = refined_dir / f"{files.analysis_dir.name}_DAPI_PV_{targets['dTomato'][1]}_{center_label}_three_plane_comparison.png"
        self.write_comparison(rendered_channels, d_tomato_label, comparison_path)
        report["comparison_figure"] = str(comparison_path)
        with (files.output_dir / "processing_settings.json").open("w") as handle:
            json.dump(report, handle, indent=2)
        print(json.dumps(report, indent=2))


if __name__ == "__main__":
    ProcessingRun.from_command_line().run()
