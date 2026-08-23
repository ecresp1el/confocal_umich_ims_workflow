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
