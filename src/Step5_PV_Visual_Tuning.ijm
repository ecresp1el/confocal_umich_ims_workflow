// ============================================================================
// STEP 5 — OPTIONAL PV VISUAL TUNING (ONE IMAGE AT A TIME)
//
// Purpose
//   Create a presentation-only PV refinement from one existing grayscale
//   *_PV_raw.tif image from a Step 4 ROI.
//
// It never changes the selected input file, the prepared Z-stack, ROI set,
// or Step 3/4 outputs. Results are written to a new PV_visual_tuning folder
// next to the chosen source image.
//
// Default operations (both adjustable)
//   1. One Despeckle pass: a 3 x 3 median filter.
//   2. Light Gaussian smoothing: sigma 0.35 pixels.
//
// These settings are deliberately conservative. Do not repeat Despeckle or
// use a large Gaussian sigma when fine PV-positive processes matter.
// ============================================================================

requires("1.53");

// ----------------------------------------------------------------------------
// 0. SELECT THE STEP 3 COMPOSITE, THEN DISCOVER STEP 4 PV RAW IMAGES
// ----------------------------------------------------------------------------
Dialog.create("Step 5 — PV visual tuning");
Dialog.addMessage(
    "Step 5 will find the raw PV images already made by Step 4.\n\n" +
    "Select the same *_MAX_merged_composite.tif used to run Step 4.\n" +
    "Then choose one discovered ROI PV image to tune.\n\n" +
    "The source image, ROIs, and prior outputs will not be changed."
);
Dialog.show();

compositePath = File.openDialog(
    "Step 5 — Select *_MAX_merged_composite.tif used for Step 4"
);

if (compositePath == "")
    exit("No file was selected. Nothing was changed.");

compositeName = File.getName(compositePath);
compositeFolder = File.getParent(compositePath) + File.separator;
compositeLower = toLowerCase(compositeName);
dotPosition = lastIndexOf(compositeName, ".");
if (dotPosition > 0)
    compositeBase = substring(compositeName, 0, dotPosition);
else
    compositeBase = compositeName;

if (!endsWith(compositeLower, ".tif") && !endsWith(compositeLower, ".tiff"))
    exit("Step 5 expects the editable TIFF created by Step 3.");

if (!endsWith(compositeBase, "_MAX_merged_composite"))
    exit(
        "This does not look like the Step 3 editable composite.\n\n" +
        "Expected a filename ending in:\n" +
        "_MAX_merged_composite.tif"
    );

// Input location:
// <Sample>_FijiAnalysis/02_max_projection_and_figures/02_complete_merge/file.tif
step3Folder = File.getParent(compositeFolder) + File.separator;
analysisFolder = File.getParent(step3Folder) + File.separator;
roiOutputsFolder =
    analysisFolder +
    "03_ROI_analysis" + File.separator +
    "02_ROI_outputs" + File.separator;

if (!File.exists(roiOutputsFolder))
    exit(
        "STEP 4 ROI OUTPUTS WERE NOT FOUND.\n\n" +
        "Step 5 looked for:\n" + roiOutputsFolder + "\n\n" +
        "Run Step 4 on this composite first, save at least one ROI, and try again."
    );

roiFolders = getFileList(roiOutputsFolder);
candidateLabels = newArray(lengthOf(roiFolders));
candidatePaths = newArray(lengthOf(roiFolders));
candidateCount = 0;

for (r = 0; r < lengthOf(roiFolders); r++) {
    roiFolderName = roiFolders[r];
    if (endsWith(roiFolderName, "/")) {
        roiFolderPath = roiOutputsFolder + roiFolderName;
        roiFiles = getFileList(roiFolderPath);
        for (f = 0; f < lengthOf(roiFiles); f++) {
            roiFileName = roiFiles[f];
            roiFileLower = toLowerCase(roiFileName);
            if (endsWith(roiFileLower, "_pv_raw.tif") || endsWith(roiFileLower, "_pv_raw.tiff")) {
                candidateLabels[candidateCount] =
                    substring(roiFolderName, 0, lengthOf(roiFolderName) - 1) +
                    " — " + roiFileName;
                candidatePaths[candidateCount] = roiFolderPath + roiFileName;
                candidateCount++;
            }
        }
    }
}

if (candidateCount == 0)
    exit(
        "STEP 4 WAS FOUND, BUT NO RAW PV ROI TIFF WAS FOUND.\n\n" +
        "Expected a file ending in _PV_raw.tif inside:\n" + roiOutputsFolder
    );

// Keep only populated entries before presenting the chooser.
choiceLabels = newArray(candidateCount);
choicePaths = newArray(candidateCount);
for (q = 0; q < candidateCount; q++) {
    choiceLabels[q] = candidateLabels[q];
    choicePaths[q] = candidatePaths[q];
}

Dialog.create("Step 5 — PV images found");
Dialog.addMessage(
    "Found " + candidateCount + " raw PV ROI image(s).\n\n" +
    "Choose the one image you want to refine now.\n" +
    "You can rerun Step 5 for another ROI later."
);
Dialog.addChoice("PV ROI image:", choiceLabels, choiceLabels[0]);
Dialog.show();
selectedLabel = Dialog.getChoice();
selectedIndex = -1;
for (q = 0; q < candidateCount; q++) {
    if (choiceLabels[q] == selectedLabel)
        selectedIndex = q;
}

if (selectedIndex < 0)
    exit("The selected PV image could not be resolved. Nothing was changed.");

inputPath = choicePaths[selectedIndex];
inputName = File.getName(inputPath);

open(inputPath);
sourceTitle = getTitle();

if (bitDepth == 24) {
    close();
    exit(
        "This appears to be an RGB display image.\n\n" +
        "Step 5 expected the grayscale *_PV_raw.tif from Step 4."
    );
}

getMinAndMax(defaultDisplayMin, defaultDisplayMax);

Dialog.create("Step 5 — PV visual tuning");
Dialog.addMessage(
    "A duplicate will be processed; the selected source TIFF remains untouched.\n\n" +
    "Start gently. A single median Despeckle pass suppresses isolated pixels.\n" +
    "Keep Gaussian sigma at or below about 0.5 px if thin PV processes matter.\n\n" +
    "The display limits affect only the saved green preview, not the grayscale tuned TIFF."
);
Dialog.addCheckbox("Apply one 3 x 3 median Despeckle pass", true);
Dialog.addNumber("Gaussian smoothing sigma (pixels; 0 disables it)", 0.35, 2);
Dialog.addNumber("Green preview display minimum", defaultDisplayMin, 3);
Dialog.addNumber("Green preview display maximum", defaultDisplayMax, 3);
Dialog.show();

applyDespeckle = Dialog.getCheckbox();
gaussianSigma = Dialog.getNumber();
displayMin = Dialog.getNumber();
displayMax = Dialog.getNumber();

if (gaussianSigma < 0)
    exit("Gaussian sigma cannot be negative. Nothing was saved.");

if (displayMax <= displayMin)
    exit("Display maximum must be greater than display minimum. Nothing was saved.");

// Work only on a duplicate. The opened source stays available for comparison.
selectWindow(sourceTitle);
run("Duplicate...", "title=PV_Visual_Tuning_Work");
workTitle = getTitle();

if (applyDespeckle)
    run("Despeckle");

if (gaussianSigma > 0)
    run("Gaussian Blur...", "sigma=" + gaussianSigma);

inputDirectory = File.getDirectory(inputPath);
outputDirectory = inputDirectory + "PV_visual_tuning" + File.separator;
File.makeDirectory(outputDirectory);

baseName = replace(inputName, ".tif", "");
processedPath = outputDirectory + baseName + "_PV_tuned_grayscale.tif";
previewTiffPath = outputDirectory + baseName + "_PV_tuned_green_preview.tif";
previewPngPath = outputDirectory + baseName + "_PV_tuned_green_preview.png";
settingsPath = outputDirectory + baseName + "_PV_tuning_settings.txt";

// Grayscale output contains the optional median/Gaussian operations. It is
// clearly labeled as visualization-only and should not replace raw data for
// measurement or threshold-based quantification.
saveAs("Tiff", processedPath);

// Create a separate, display-baked green preview with user-selected limits.
setMinAndMax(displayMin, displayMax);
run("Green");
run("RGB Color");
saveAs("Tiff", previewTiffPath);
saveAs("PNG", previewPngPath);

settings =
    "STEP 5 — OPTIONAL PV VISUAL TUNING\n" +
    "====================================\n\n" +
    "INPUT (unchanged): " + inputPath + "\n" +
    "OUTPUT GRAYSCALE (visualization-only): " + processedPath + "\n" +
    "OUTPUT GREEN PREVIEW (display-baked): " + previewTiffPath + "\n\n" +
    "One-pass 3 x 3 median Despeckle: " + applyDespeckle + "\n" +
    "Gaussian smoothing sigma (px): " + d2s(gaussianSigma, 3) + "\n" +
    "Green preview display minimum: " + d2s(displayMin, 3) + "\n" +
    "Green preview display maximum: " + d2s(displayMax, 3) + "\n\n" +
    "IMPORTANT\n" +
    "Source TIFF, ROI, Z-stack, and Step 3/4 outputs were not modified.\n" +
    "Use the raw PV image for measurement; this output is for visual presentation only.\n";
File.saveString(settings, settingsPath);

selectWindow(sourceTitle);
setMinAndMax(displayMin, displayMax);
run("Green");

selectWindow(workTitle);
rename("PV tuned preview — visualization only");

Dialog.create("Step 5 complete");
Dialog.addMessage(
    "The raw source was not changed.\n\n" +
    "Outputs:\n" +
    outputDirectory + "\n\n" +
    "Use the left/open source and the tuned preview to judge whether fine PV processes remain intact."
);
Dialog.show();
