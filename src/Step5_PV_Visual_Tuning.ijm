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
// Default operations (all adjustable)
//   1. Optional bright-outlier suppression for isolated hot pixels.
//   2. Optional median filtering for tunable despeckling.
//   3. Optional light Gaussian smoothing.
//
// These settings are deliberately conservative. Keep the hot-pixel radius and
// median radius small, and avoid large Gaussian sigma when fine PV-positive
// processes matter.
// ============================================================================

requires("1.53");

// ----------------------------------------------------------------------------
// 0. SELECT ONE FIJI ANALYSIS FOLDER, THEN DISCOVER ITS STEP 4 PV IMAGES
// ----------------------------------------------------------------------------
Dialog.create("Step 5 — PV visual tuning");
Dialog.addMessage(
    "Step 5 will find the raw PV images already made by Step 4.\n\n" +
    "Select the exact *_FijiAnalysis folder for the sample you want to work on.\n" +
    "Step 5 will inspect its existing pipeline outputs and find the PV ROI images.\n\n" +
    "The source image, ROIs, and prior outputs will not be changed."
);
Dialog.show();

analysisFolder = getDirectory(
    "Step 5 — Select the exact *_FijiAnalysis folder to tune"
);

if (analysisFolder == "")
    exit("No folder was selected. Nothing was changed.");

// getDirectory() returns a path ending in the folder separator.
analysisFolderName = substring(analysisFolder, 0, lengthOf(analysisFolder) - 1);
lastSeparator = lastIndexOf(analysisFolderName, File.separator);
if (lastSeparator >= 0)
    analysisFolderName = substring(analysisFolderName, lastSeparator + 1);

if (!endsWith(analysisFolderName, "_FijiAnalysis"))
    exit(
        "This does not look like a Fiji analysis folder.\n\n" +
        "Select the folder whose name ends in:\n" +
        "_FijiAnalysis"
    );

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

// Nothing is written until the user reviews a live preview and explicitly
// chooses "Accept and save this preview".
reviewComplete = 0;
while (reviewComplete == 0) {
    Dialog.create("Step 5 — Choose a PV tuning trial");
    Dialog.addMessage(
        "The source TIFF stays unchanged. This trial is displayed before anything is saved.\n\n" +
        "Processing order: bright hot-pixel suppression, median despeckling, then smoothing.\n" +
        "Start conservatively and compare each trial against the raw PV source.\n\n" +
        "After previewing, you can retune, accept and save, or cancel."
    );
    Dialog.addCheckbox("Suppress isolated bright hot pixels", false);
    Dialog.addNumber("Hot-pixel radius", 1, 0, 8, "pixels");
    Dialog.addNumber("Hot-pixel threshold", 200, 0, 8, "intensity units");
    Dialog.addCheckbox("Apply median despeckling", true);
    Dialog.addNumber("Median filter radius", 1, 0, 8, "pixels");
    Dialog.addNumber("Gaussian smoothing sigma", 0.35, 2, 8, "pixels (0 = disabled)");
    Dialog.addNumber("Green preview display minimum", defaultDisplayMin, 0, 8, "raw intensity");
    Dialog.addNumber("Green preview display maximum", defaultDisplayMax, 0, 8, "raw intensity");
    Dialog.show();

    suppressHotPixels = Dialog.getCheckbox();
    hotPixelRadius = Dialog.getNumber();
    hotPixelThreshold = Dialog.getNumber();
    applyMedian = Dialog.getCheckbox();
    medianRadius = Dialog.getNumber();
    gaussianSigma = Dialog.getNumber();
    displayMin = Dialog.getNumber();
    displayMax = Dialog.getNumber();

    if (gaussianSigma < 0)
        exit("Gaussian sigma cannot be negative. Nothing was saved.");

    if (suppressHotPixels && (hotPixelRadius < 1 || hotPixelThreshold <= 0))
        exit("Hot-pixel radius and threshold must be greater than zero. Nothing was saved.");

    if (applyMedian && medianRadius < 1)
        exit("Median filter radius must be at least 1 pixel. Nothing was saved.");

    if (displayMax <= displayMin)
        exit("Display maximum must be greater than display minimum. Nothing was saved.");

    // Work only on a duplicate. The source remains the visual benchmark.
    selectWindow(sourceTitle);
    setMinAndMax(displayMin, displayMax);
    run("Green");
    run("Duplicate...", "title=PV_Tuned_Trial");
    workTitle = getTitle();

    if (suppressHotPixels)
        run(
            "Remove Outliers...",
            "radius=" + hotPixelRadius +
            " threshold=" + hotPixelThreshold +
            " which=Bright"
        );

    if (applyMedian)
        run("Median...", "radius=" + medianRadius);

    if (gaussianSigma > 0)
        run("Gaussian Blur...", "sigma=" + gaussianSigma);

    setMinAndMax(displayMin, displayMax);
    run("Green");
    run("Tile");

    reviewChoices = newArray(
        "Retune settings",
        "Accept and save this preview",
        "Cancel without saving"
    );
    Dialog.create("Step 5 — Review raw versus tuned PV");
    Dialog.addMessage(
        "The raw PV source and tuned trial are open side by side.\n\n" +
        "Look specifically for remaining isolated specks/hot pixels, retained fine PV processes,\n" +
        "and whether cell borders still look natural.\n\n" +
        "If real small structures disappear, lower the median radius or disable hot-pixel suppression."
    );
    Dialog.addChoice("Next action:", reviewChoices, "Retune settings");
    Dialog.show();
    reviewDecision = Dialog.getChoice();

    if (reviewDecision == "Retune settings") {
        selectWindow(workTitle);
        close();
    }

    if (reviewDecision == "Cancel without saving") {
        selectWindow(workTitle);
        close();
        selectWindow(sourceTitle);
        close();
        exit("Step 5 cancelled. Nothing was saved.");
    }

    if (reviewDecision == "Accept and save this preview")
        reviewComplete = 1;
}

inputDirectory = File.getDirectory(inputPath);
outputDirectory = inputDirectory + "PV_visual_tuning" + File.separator;
File.makeDirectory(outputDirectory);

baseName = replace(inputName, ".tif", "");
runNumber = 1;
runLabel = "_PV_tuning_run_" + runNumber;
while (File.exists(outputDirectory + baseName + runLabel + "_settings.txt")) {
    runNumber++;
    runLabel = "_PV_tuning_run_" + runNumber;
}

processedPath = outputDirectory + baseName + runLabel + "_grayscale.tif";
previewTiffPath = outputDirectory + baseName + runLabel + "_green_preview.tif";
previewPngPath = outputDirectory + baseName + runLabel + "_green_preview.png";
settingsPath = outputDirectory + baseName + runLabel + "_settings.txt";

// Save the accepted trial as grayscale first. The green preview is made from
// a separate duplicate, so its display color never changes this TIFF's pixels.
selectWindow(workTitle);
run("Grays");
saveAs("Tiff", processedPath);
// Fiji may rename the open image to the saved filename. Capture that title
// before building the separate green preview and showing the completion state.
workTitle = getTitle();

setMinAndMax(displayMin, displayMax);
run("Green");
run("Duplicate...", "title=PV_Tuned_Green_Preview_Save");
previewTitle = getTitle();
run("RGB Color");
saveAs("Tiff", previewTiffPath);
saveAs("PNG", previewPngPath);
close();

settings =
    "STEP 5 — OPTIONAL PV VISUAL TUNING\n" +
    "====================================\n\n" +
    "INPUT (unchanged): " + inputPath + "\n" +
    "RUN: " + runNumber + "\n" +
    "OUTPUT GRAYSCALE (visualization-only): " + processedPath + "\n" +
    "OUTPUT GREEN PREVIEW (display-baked): " + previewTiffPath + "\n\n" +
    "Bright hot-pixel suppression: " + suppressHotPixels + "\n" +
    "Hot-pixel radius (px): " + d2s(hotPixelRadius, 0) + "\n" +
    "Hot-pixel threshold: " + d2s(hotPixelThreshold, 0) + "\n" +
    "Median despeckling: " + applyMedian + "\n" +
    "Median filter radius (px): " + d2s(medianRadius, 0) + "\n" +
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

// Continue directly into the same ROI's multi-channel paper-figure review.
// This review writes files only after the user explicitly accepts the set.
launchFinalChannelReview(inputDirectory, processedPath);

Dialog.create("Step 5 complete");
Dialog.addMessage(
    "The raw source was not changed.\n\n" +
    "Saved PV run:\n" + outputDirectory + "\n\n" +
    "The matching DAPI, PV, dTomato, pairwise, and full-merge review windows were opened."
);
Dialog.show();


// ============================================================================
// FINAL MULTI-CHANNEL REVIEW (SAVED ONLY AFTER EXPLICIT ACCEPTANCE)
// ============================================================================
function launchFinalChannelReview(roiFolder, acceptedPVPath) {
    roiFiles = getFileList(roiFolder);
    dapiPath = "";
    dtomPath = "";

    for (i = 0; i < lengthOf(roiFiles); i++) {
        candidateName = roiFiles[i];
        candidateLower = toLowerCase(candidateName);
        if (endsWith(candidateLower, "_dapi_raw.tif"))
            dapiPath = roiFolder + candidateName;
        if (endsWith(candidateLower, "_raw.tif") && indexOf(candidateLower, "dtom") >= 0)
            dtomPath = roiFolder + candidateName;
    }

    if (dapiPath == "" || dtomPath == "") {
        Dialog.create("Step 5 — final review unavailable");
        Dialog.addMessage(
            "PV saved, but the matching DAPI or dTomato raw ROI TIFF was not found.\n\n" +
            "Expected in:\n" + roiFolder
        );
        Dialog.show();
        return;
    }

    // The three source windows remain open while the user sets their display.
    open(dapiPath);
    dapiTitle = getTitle();
    run("Blue");
    run("Brightness/Contrast...");
    waitForUser("Step 5 — Tune DAPI", "Adjust DAPI brightness/contrast, then click OK.");
    getMinAndMax(dapiMin, dapiMax);

    open(acceptedPVPath);
    finalPVTitle = getTitle();
    run("Green");
    run("Brightness/Contrast...");
    waitForUser("Step 5 — Tune PV", "Adjust the accepted PV brightness/contrast, then click OK.");
    getMinAndMax(finalPVMin, finalPVMax);

    open(dtomPath);
    dtomTitle = getTitle();
    run("Red");
    run("Brightness/Contrast...");
    waitForUser("Step 5 — Tune dTomato", "Adjust dTomato brightness/contrast, then click OK.");
    getMinAndMax(dtomMin, dtomMax);

    dapiPVTitle = makeFinalPair(dapiTitle, finalPVTitle, "DAPI + PV review", "Blue", "Green", dapiMin, dapiMax, finalPVMin, finalPVMax);
    dapiDtomTitle = makeFinalPair(dapiTitle, dtomTitle, "DAPI + dTomato review", "Blue", "Red", dapiMin, dapiMax, dtomMin, dtomMax);
    pvDtomTitle = makeFinalPair(finalPVTitle, dtomTitle, "PV + dTomato review", "Green", "Red", finalPVMin, finalPVMax, dtomMin, dtomMax);
    fullMergeTitle = makeFinalMerge(dapiTitle, finalPVTitle, dtomTitle, dapiMin, dapiMax, finalPVMin, finalPVMax, dtomMin, dtomMax);

    run("Tile");
    finalChoices = newArray("Accept and save final figure set", "Leave this review unsaved");
    Dialog.create("Step 5 — final figure review");
    Dialog.addMessage(
        "Review the three individual channels, three pairwise merges, and full merge.\n\n" +
        "Accepting saves this exact display state and a linked settings record."
    );
    Dialog.addChoice("Final decision:", finalChoices, "Leave this review unsaved");
    Dialog.show();
    finalDecision = Dialog.getChoice();

    if (finalDecision == "Accept and save final figure set")
        saveFinalFigureSet(roiFolder, acceptedPVPath, dapiTitle, finalPVTitle, dtomTitle, dapiPVTitle, dapiDtomTitle, pvDtomTitle, fullMergeTitle, dapiMin, dapiMax, finalPVMin, finalPVMax, dtomMin, dtomMax);
}

function makeFinalPair(titleA, titleB, pairName, colorA, colorB, minA, maxA, minB, maxB) {
    selectWindow(titleA);
    run("Duplicate...", "title=PAIR_A_TMP");
    pairA = getTitle();
    applyFinalLUT(colorA);
    setMinAndMax(minA, maxA);
    selectWindow(titleB);
    run("Duplicate...", "title=PAIR_B_TMP");
    pairB = getTitle();
    applyFinalLUT(colorB);
    setMinAndMax(minB, maxB);
    run("Merge Channels...", "c1=[" + pairA + "] c2=[" + pairB + "] create");
    Stack.setDisplayMode("composite");
    Stack.setActiveChannels("11");
    run("RGB Color");
    rename(pairName);
    return getTitle();
}

function makeFinalMerge(dapiTitle, pvTitle, dtomTitle, dapiMin, dapiMax, pvMin, pvMax, dtomMin, dtomMax) {
    run("Merge Channels...", "c1=[" + dapiTitle + "] c2=[" + pvTitle + "] c3=[" + dtomTitle + "] create");
    Stack.setChannel(1); applyFinalLUT("Blue"); setMinAndMax(dapiMin, dapiMax);
    Stack.setChannel(2); applyFinalLUT("Green"); setMinAndMax(pvMin, pvMax);
    Stack.setChannel(3); applyFinalLUT("Red"); setMinAndMax(dtomMin, dtomMax);
    Stack.setDisplayMode("composite");
    Stack.setActiveChannels("111");
    run("RGB Color");
    rename("DAPI + PV + dTomato full merge review");
    return getTitle();
}

function applyFinalLUT(colorName) {
    if (colorName == "Blue") run("Blue");
    if (colorName == "Green") run("Green");
    if (colorName == "Red") run("Red");
}

function saveFinalFigureSet(roiFolder, acceptedPVPath, dapiTitle, pvTitle, dtomTitle, dapiPVTitle, dapiDtomTitle, pvDtomTitle, fullMergeTitle, dapiMin, dapiMax, pvMin, pvMax, dtomMin, dtomMax) {
    finalFolder = roiFolder + "final_figure_review" + File.separator;
    File.makeDirectory(finalFolder);
    finalRun = 1;
    while (File.exists(finalFolder + "final_figure_run_" + finalRun + "_settings.txt"))
        finalRun++;
    finalStem = finalFolder + "final_figure_run_" + finalRun;

    saveFinalRGB(dapiTitle, finalStem + "_DAPI_blue");
    saveFinalRGB(pvTitle, finalStem + "_PV_green");
    saveFinalRGB(dtomTitle, finalStem + "_dTomato_red");
    saveFinalRGB(dapiPVTitle, finalStem + "_DAPI_PLUS_PV");
    saveFinalRGB(dapiDtomTitle, finalStem + "_DAPI_PLUS_dTomato");
    saveFinalRGB(pvDtomTitle, finalStem + "_PV_PLUS_dTomato");
    saveFinalRGB(fullMergeTitle, finalStem + "_DAPI_PV_dTomato_merge");

    finalSettings =
        "STEP 5 — ACCEPTED FINAL FIGURE SET\n" +
        "====================================\n\n" +
        "Accepted PV input: " + acceptedPVPath + "\n\n" +
        "DAPI display min/max: " + d2s(dapiMin, 3) + " / " + d2s(dapiMax, 3) + "\n" +
        "PV display min/max: " + d2s(pvMin, 3) + " / " + d2s(pvMax, 3) + "\n" +
        "dTomato display min/max: " + d2s(dtomMin, 3) + " / " + d2s(dtomMax, 3) + "\n\n" +
        "This figure set is visualization-only. Raw ROI TIFFs were not modified.\n";
    File.saveString(finalSettings, finalStem + "_settings.txt");
}

function saveFinalRGB(windowTitle, outputStem) {
    selectWindow(windowTitle);
    run("Duplicate...", "title=FINAL_SAVE_TMP");
    run("RGB Color");
    saveAs("Tiff", outputStem + ".tif");
    saveAs("PNG", outputStem + ".png");
    close();
}
