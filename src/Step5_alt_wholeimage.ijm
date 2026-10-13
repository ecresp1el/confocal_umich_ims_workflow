// ============================================================================
// STEP 5 ALT — WHOLE-IMAGE PV VISUAL TUNING
//
// Presentation-only refinement of the full-field PV maximum projection made
// by Step 3. This variant never uses, creates, or changes ROIs.
//
// INPUT (automatically found after selecting one *_FijiAnalysis folder):
//   02_max_projection_and_figures/01_individual_channels/raw_max_tiffs/
//   *_MAX_PV.tif, *_MAX_DAPI.tif, and the exact dTomato marker TIFF
//
// OUTPUT:
//   02_max_projection_and_figures/06_whole_image_PV_visual_tuning/
//
// Raw MAX TIFFs, Step 3 figures, ROIs, and source data are never modified.
// ============================================================================

requires("1.53");

// ----------------------------------------------------------------------------
// 0. SELECT ONE ANALYSIS FOLDER, THEN FIND ITS STEP 3 FULL-FIELD RAW MAX TIFFS
// ----------------------------------------------------------------------------
Dialog.create("Step 5 alt — whole-image PV visual tuning");
Dialog.addMessage(
    "This is the full-image alternative to Step 5. It does not use ROIs.\n\n" +
    "Select one exact *_FijiAnalysis folder. The macro will find that sample's\n" +
    "Step 3 raw full-field MAX projections, tune PV, then open the DAPI/PV/dTomato\n" +
    "review set.\n\n" +
    "Raw MAX TIFFs and all previous outputs remain unchanged."
);
Dialog.show();

analysisFolder = getDirectory(
    "Step 5 alt — Select the exact *_FijiAnalysis folder to tune"
);
if (analysisFolder == "")
    exit("No folder was selected. Nothing was changed.");

analysisFolderName = substring(analysisFolder, 0, lengthOf(analysisFolder) - 1);
lastSeparator = lastIndexOf(analysisFolderName, File.separator);
if (lastSeparator >= 0)
    analysisFolderName = substring(analysisFolderName, lastSeparator + 1);
if (!endsWith(analysisFolderName, "_FijiAnalysis"))
    exit("Select the exact folder whose name ends in _FijiAnalysis.");

rawMaxFolder = analysisFolder +
    "02_max_projection_and_figures" + File.separator +
    "01_individual_channels" + File.separator +
    "raw_max_tiffs" + File.separator;

if (!File.exists(rawMaxFolder))
    exit(
        "STEP 3 RAW FULL-IMAGE MAX TIFFS WERE NOT FOUND.\n\n" +
        "Expected:\n" + rawMaxFolder + "\n\n" +
        "Run Step 3 for this sample first."
    );

dtomMarker = findDtomMarker(analysisFolder);
if (dtomMarker == "")
    exit(
        "The Step 1 channel map did not contain a marker with 'dtom'.\n\n" +
        "No image was changed or saved."
    );

rawFiles = getFileList(rawMaxFolder);
pvPath = "";
dapiPath = "";
dtomPath = "";
dtomSuffix = "_max_" + toLowerCase(dtomMarker) + ".tif";
for (i = 0; i < lengthOf(rawFiles); i++) {
    rawFileName = rawFiles[i];
    rawFileLower = toLowerCase(rawFileName);
    // Ignore macOS metadata sidecars (._filename.tif).
    if (!startsWith(rawFileName, ".")) {
        if (endsWith(rawFileLower, "_max_pv.tif") || endsWith(rawFileLower, "_max_pv.tiff"))
            pvPath = rawMaxFolder + rawFileName;
        if (endsWith(rawFileLower, "_max_dapi.tif") || endsWith(rawFileLower, "_max_dapi.tiff"))
            dapiPath = rawMaxFolder + rawFileName;
        if (endsWith(rawFileLower, dtomSuffix))
            dtomPath = rawMaxFolder + rawFileName;
    }
}

if (pvPath == "")
    exit(
        "No full-image raw PV MAX TIFF was found.\n\n" +
        "Expected a file ending in _MAX_PV.tif inside:\n" + rawMaxFolder
    );

if (dapiPath == "" || dtomPath == "")
    exit(
        "The complete full-image review set could not be identified.\n\n" +
        "Expected DAPI: *_MAX_DAPI.tif\n" +
        "Expected dTomato: *_MAX_" + dtomMarker + ".tif\n\n" +
        "Expected folder:\n" + rawMaxFolder + "\n\n" +
        "No image was changed or saved."
    );

// Confirm source identity before any preview is created.
Dialog.create("Step 5 alt — confirm whole-image inputs");
Dialog.addMessage(
    "The Step 1 channel map and Step 3 raw MAX folder identified:\n\n" +
    "PV raw: " + File.getName(pvPath) + "\n" +
    "DAPI raw: " + File.getName(dapiPath) + "\n" +
    "dTomato marker: " + dtomMarker + "\n" +
    "dTomato raw: " + File.getName(dtomPath) + "\n\n" +
    "These must be full-field Step 3 raw MAX TIFFs, not ROI files."
);
Dialog.addCheckbox("Yes — use these identified whole-image inputs.", false);
Dialog.show();
if (!Dialog.getCheckbox())
    exit("Cancelled before processing. Nothing was changed.");

open(pvPath);
sourceTitle = getTitle();
if (bitDepth == 24) {
    close();
    exit("The selected PV source appears to be RGB. Step 5 alt requires the grayscale Step 3 raw MAX TIFF.");
}
getMinAndMax(defaultDisplayMin, defaultDisplayMax);

// ----------------------------------------------------------------------------
// 1. PV TRIALS — ALL WORK IS ON A DUPLICATE UNTIL THE USER ACCEPTS
// ----------------------------------------------------------------------------
reviewComplete = 0;
while (reviewComplete == 0) {
    Dialog.create("Step 5 alt — choose a whole-image PV tuning trial");
    Dialog.addMessage(
        "The raw PV MAX projection remains unchanged.\n\n" +
        "Processing order: bright hot-pixel suppression, median despeckling, then smoothing.\n" +
        "Start conservatively to retain thin PV-positive processes."
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

    selectWindow(sourceTitle);
    setMinAndMax(displayMin, displayMax);
    run("Green");
    run("Duplicate...", "title=PV_WholeImage_Tuned_Trial");
    workTitle = getTitle();

    if (suppressHotPixels)
        run("Remove Outliers...", "radius=" + hotPixelRadius + " threshold=" + hotPixelThreshold + " which=Bright");
    if (applyMedian)
        run("Median...", "radius=" + medianRadius);
    if (gaussianSigma > 0)
        run("Gaussian Blur...", "sigma=" + gaussianSigma);

    setMinAndMax(displayMin, displayMax);
    run("Green");
    run("Tile");

    reviewChoices = newArray("Retune settings", "Accept and save this preview", "Cancel without saving");
    Dialog.create("Step 5 alt — review raw versus tuned whole-image PV");
    Dialog.addMessage(
        "The raw full-field PV MAX and tuned trial are open side by side.\n\n" +
        "Check for remaining hot pixels, retention of fine processes, and natural cell borders.\n" +
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
        exit("Step 5 alt cancelled. Nothing was saved.");
    }
    if (reviewDecision == "Accept and save this preview")
        reviewComplete = 1;
}

// ----------------------------------------------------------------------------
// 2. SAVE ONLY THE ACCEPTED PV TRIAL, OUTSIDE THE RAW MAX FOLDER
// ----------------------------------------------------------------------------
outputDirectory = analysisFolder +
    "02_max_projection_and_figures" + File.separator +
    "06_whole_image_PV_visual_tuning" + File.separator;
File.makeDirectory(outputDirectory);

inputName = File.getName(pvPath);
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

selectWindow(workTitle);
run("Grays");
saveAs("Tiff", processedPath);
workTitle = getTitle();
setMinAndMax(displayMin, displayMax);
run("Green");
run("Duplicate...", "title=PV_WholeImage_Green_Preview_Save");
previewTitle = getTitle();
run("RGB Color");
saveAs("Tiff", previewTiffPath);
saveAs("PNG", previewPngPath);
close();

settings =
    "STEP 5 ALT — WHOLE-IMAGE PV VISUAL TUNING\n" +
    "============================================\n\n" +
    "INPUT RAW MAX (unchanged): " + pvPath + "\n" +
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
    "Raw full-field MAX TIFFs and earlier pipeline outputs were not modified.\n" +
    "Use raw MAX images for measurement; these files are for visual presentation only.\n";
File.saveString(settings, settingsPath);

selectWindow(sourceTitle);
setMinAndMax(displayMin, displayMax);
run("Green");
selectWindow(workTitle);
rename("PV whole-image tuned preview — visualization only");
workTitle = getTitle();

launchFinalChannelReview(dapiPath, processedPath, dtomPath, dtomMarker, outputDirectory);

Dialog.create("Step 5 alt complete");
Dialog.addMessage(
    "The full-field raw MAX sources were not changed.\n\n" +
    "Saved PV run:\n" + outputDirectory + "\n\n" +
    "The matching DAPI, PV, dTomato, pairwise, and full-merge review windows were opened."
);
Dialog.show();


// ============================================================================
// FINAL MULTI-CHANNEL REVIEW (SAVED ONLY AFTER EXPLICIT ACCEPTANCE)
// ============================================================================
function launchFinalChannelReview(dapiPath, acceptedPVPath, dtomPath, dtomMarker, outputDirectory) {
    if (dapiPath == "" || dtomPath == "") {
        Dialog.create("Step 5 alt — final review unavailable");
        Dialog.addMessage(
            "The accepted PV run was saved, but a matching DAPI or exact dTomato raw MAX TIFF was not found.\n\n" +
            "Expected dTomato marker: " + dtomMarker
        );
        Dialog.show();
        return;
    }

    Dialog.create("Step 5 alt — confirm final-review channels");
    Dialog.addMessage(
        "The Step 1 channel map identified these full-field final-review inputs:\n\n" +
        "DAPI raw MAX: " + File.getName(dapiPath) + "\n" +
        "PV tuned: " + File.getName(acceptedPVPath) + "\n" +
        "dTomato marker: " + dtomMarker + "\n" +
        "dTomato raw MAX: " + File.getName(dtomPath) + "\n\n" +
        "The selected dTomato file must match the Step 1 marker exactly."
    );
    Dialog.addCheckbox("Yes — use these identified channels.", false);
    Dialog.show();
    if (!Dialog.getCheckbox())
        return;

    open(dapiPath);
    dapiTitle = getTitle();
    run("Blue");
    run("Brightness/Contrast...");
    waitForUser("Step 5 alt — Tune DAPI", "Adjust DAPI brightness/contrast, then click OK.");
    getMinAndMax(dapiMin, dapiMax);

    open(acceptedPVPath);
    finalPVTitle = getTitle();
    run("Green");
    run("Brightness/Contrast...");
    waitForUser("Step 5 alt — Tune PV", "Adjust the accepted PV brightness/contrast, then click OK.");
    getMinAndMax(finalPVMin, finalPVMax);

    open(dtomPath);
    dtomTitle = getTitle();
    run("Red");
    run("Brightness/Contrast...");
    waitForUser("Step 5 alt — Tune dTomato", "Adjust dTomato brightness/contrast, then click OK.");
    getMinAndMax(dtomMin, dtomMax);

    dapiPVTitle = makeFinalPair(dapiTitle, finalPVTitle, "DAPI + PV whole-image review", "Blue", "Green", dapiMin, dapiMax, finalPVMin, finalPVMax);
    dapiDtomTitle = makeFinalPair(dapiTitle, dtomTitle, "DAPI + dTomato whole-image review", "Blue", "Red", dapiMin, dapiMax, dtomMin, dtomMax);
    pvDtomTitle = makeFinalPair(finalPVTitle, dtomTitle, "PV + dTomato whole-image review", "Green", "Red", finalPVMin, finalPVMax, dtomMin, dtomMax);
    fullMergeTitle = makeFinalMerge(dapiTitle, finalPVTitle, dtomTitle, dapiMin, dapiMax, finalPVMin, finalPVMax, dtomMin, dtomMax);

    run("Tile");
    finalChoices = newArray("Accept and save final figure set", "Leave this review unsaved");
    Dialog.create("Step 5 alt — final whole-image figure review");
    Dialog.addMessage(
        "Review the three full-field channels, three pairwise merges, and full merge.\n\n" +
        "Accepting saves this exact display state and a linked settings record."
    );
    Dialog.addChoice("Final decision:", finalChoices, "Leave this review unsaved");
    Dialog.show();
    if (Dialog.getChoice() == "Accept and save final figure set")
        saveFinalFigureSet(outputDirectory, acceptedPVPath, dapiTitle, finalPVTitle, dtomTitle, dapiPVTitle, dapiDtomTitle, pvDtomTitle, fullMergeTitle, dapiMin, dapiMax, finalPVMin, finalPVMax, dtomMin, dtomMax);
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
    rename("DAPI + PV + dTomato whole-image full merge review");
    return getTitle();
}

function applyFinalLUT(colorName) {
    if (colorName == "Blue") run("Blue");
    if (colorName == "Green") run("Green");
    if (colorName == "Red") run("Red");
}

function findDtomMarker(selectedAnalysisFolder) {
    channelFolder = selectedAnalysisFolder + "00_import_and_channels" + File.separator;
    if (!File.exists(channelFolder)) return "";
    channelFiles = getFileList(channelFolder);
    mapPath = "";
    for (m = 0; m < lengthOf(channelFiles); m++) {
        mapFile = toLowerCase(channelFiles[m]);
        if (endsWith(mapFile, "_channel_map.csv")) mapPath = channelFolder + channelFiles[m];
    }
    if (mapPath == "") return "";
    mapLines = split(File.openAsString(mapPath), "\n");
    for (m = 1; m < lengthOf(mapLines); m++) {
        commaIndex = indexOf(mapLines[m], ",");
        if (commaIndex >= 0) {
            markerName = replace(substring(mapLines[m], commaIndex + 1), "\"", "");
            markerName = replace(markerName, "\r", "");
            if (indexOf(toLowerCase(markerName), "dtom") >= 0) return markerName;
        }
    }
    return "";
}

function saveFinalFigureSet(outputDirectory, acceptedPVPath, dapiTitle, pvTitle, dtomTitle, dapiPVTitle, dapiDtomTitle, pvDtomTitle, fullMergeTitle, dapiMin, dapiMax, pvMin, pvMax, dtomMin, dtomMax) {
    finalFolder = outputDirectory + "final_figure_review" + File.separator;
    File.makeDirectory(finalFolder);
    finalRun = 1;
    while (File.exists(finalFolder + "whole_image_final_figure_run_" + finalRun + "_settings.txt")) finalRun++;
    finalStem = finalFolder + "whole_image_final_figure_run_" + finalRun;

    saveFinalRGB(dapiTitle, finalStem + "_DAPI_blue");
    saveFinalRGB(pvTitle, finalStem + "_PV_green");
    saveFinalRGB(dtomTitle, finalStem + "_dTomato_red");
    saveFinalRGB(dapiPVTitle, finalStem + "_DAPI_PLUS_PV");
    saveFinalRGB(dapiDtomTitle, finalStem + "_DAPI_PLUS_dTomato");
    saveFinalRGB(pvDtomTitle, finalStem + "_PV_PLUS_dTomato");
    saveFinalRGB(fullMergeTitle, finalStem + "_DAPI_PV_dTomato_merge");

    finalSettings =
        "STEP 5 ALT — ACCEPTED WHOLE-IMAGE FINAL FIGURE SET\n" +
        "=====================================================\n\n" +
        "Accepted PV input: " + acceptedPVPath + "\n\n" +
        "DAPI display min/max: " + d2s(dapiMin, 3) + " / " + d2s(dapiMax, 3) + "\n" +
        "PV display min/max: " + d2s(pvMin, 3) + " / " + d2s(pvMax, 3) + "\n" +
        "dTomato display min/max: " + d2s(dtomMin, 3) + " / " + d2s(dtomMax, 3) + "\n\n" +
        "This full-field figure set is visualization-only. Raw MAX TIFFs were not modified.\n";
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
