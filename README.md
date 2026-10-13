# Confocal UMich IMS Workflow

Sequential Fiji macros for one confocal Imaris (`.ims`) image at a time. Run the macros in order from the `src/` folder. Fiji with Bio-Formats is required.

## Workflow

### 1. Identify image channels

Macro: `src/Step1_IMS_Channel_Identification.ijm`

Input: one Imaris `.ims` image. Inspect its channels and Z-planes, then provide one biological marker label per channel.

Output: a channel-map CSV and import summary text file in `<Sample>_FijiAnalysis/00_import_and_channels/` next to the `.ims` file.

### 2. Prepare the Z-stack

Macro: `src/Step2_Prepare_ZStack.ijm`

Input: the same original `.ims` image used in Step 1. Inspect and confirm the Z-plane range to analyze.

Output: a prepared Z-stack TIFF (`*_prepared_zstack.tif`) and settings file in the sample analysis folder.

### 3. Create full-image maximum projections and figures

Macro: `src/Step3_MaxProjection_FullImageFigures.ijm`

Input: the `*_prepared_zstack.tif` produced by Step 2. The Step 1 import summary must remain in its expected analysis-folder location.

Output: raw and display-colored maximum-projection images, figures, pairwise combinations, and an editable multichannel composite (`*_MAX_merged_composite.tif`).

### 4. Draw and manage ROIs

Macro: `src/Step4_ROI_Drawer_MultiROI.ijm`

Input: the editable `*_MAX_merged_composite.tif` produced by Step 3.

Output: a persistent ROI ZIP, ROI-manifest CSV, full-field ROI overview, and crop/figure outputs for each rectangular ROI. Supports zero or more ROIs and 1–5 channels.

### 5. Optional PV visual tuning

Macro: `src/Step5_PV_Visual_Tuning.ijm`

Input: the exact `*_FijiAnalysis` folder for one selected sample. The macro inspects that folder's existing Step 4 outputs, detects its `*_PV_raw.tif` ROI images, reports how many it found, and asks the user to choose one.

Output: after an explicit source-versus-preview review and acceptance, a separately saved, visualization-only PV grayscale refinement and green display preview in a `PV_visual_tuning/` subfolder next to the chosen input. The source TIFF, ROI set, prepared Z-stack, and prior Step 3/4 outputs are not changed. The macro offers optional bright-hot-pixel suppression, adjustable median despeckling, light adjustable Gaussian smoothing, and manual display limits; use raw PV images for measurements.

For final review, Step 5 reads the Step 1 channel map and requires the exact dTomato-marked raw ROI TIFF (for example, `BiVe3dtom` or `BiVe4dtom`). It shows the identified DAPI, tuned PV, and dTomato inputs for confirmation before creating any review merges.

### 5 alt. Optional whole-image PV visual tuning

Macro: `src/Step5_alt_wholeimage.ijm`

Input: the exact `*_FijiAnalysis` folder for one selected sample. This is the full-image companion to Step 5: it automatically uses the grayscale Step 3 raw full-field MAX TIFFs in `02_max_projection_and_figures/01_individual_channels/raw_max_tiffs/`, and never uses ROI outputs.

Output: accepted, visualization-only PV tuning runs and final review figures are saved in `02_max_projection_and_figures/06_whole_image_PV_visual_tuning/`. The macro uses the same tunable hot-pixel suppression, median despeckling, smoothing, preview/accept flow, display adjustment, DAPI-blue/PV-green/dTomato-red pairwise and full merge review, and exact Step 1 dTomato-marker confirmation as the ROI-based Step 5. It never changes raw MAX TIFFs, Step 3 figures, ROI outputs, prepared Z-stacks, or source files.

### 6. Final whole-image paper figure crop

Macro: `src/Step6_Final_Figure_Crop.ijm`

Input: the exact `*_FijiAnalysis` folder after an accepted `Step5_alt_wholeimage` final figure set exists. The macro automatically uses the most recent saved dTomato-red, PV-green, and PV+dTomato final-review TIFFs.

Output: a full-resolution, presentation-only `dTomato | PV | Merge` 1 x 3 panel in `02_max_projection_and_figures/06_whole_image_PV_visual_tuning/final_crop_panels/`. You enter an initial physical width and height, then drag and rotate one native Fiji rotated rectangle on the merge; the macro applies and straightens that same geometry for all three panels. It derives an exact fixed-length scale bar from image calibration, lets you move its placement rectangle, adds it to the merge panel only, and saves the cropped TIFFs/PNGs, reusable rotated `.roi`, and exact crop/scale-bar settings. It does not modify any Step 5 input or raw image.
