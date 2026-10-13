// ============================================================================
// STEP 7 — FINAL PANEL FINISH
//
// Makes a final, presentation-only version of the most recent Step 6 crop:
//     dTomato (red) | PV (green) | PV + dTomato merge
//
// One user-reviewed freehand boundary is used on the merge. The exact same
// boundary is applied to every panel so all pixels outside the organoid are
// black. This is deliberately not an intensity threshold: include every
// neurite/process you want retained inside the boundary.
// ============================================================================

requires("1.53");

Dialog.create("Step 7 — final panel finish");
Dialog.addMessage(
    "Step 7 finishes the newest saved Step 6 crop:\n\n" +
    "dTomato (red)  |  PV (green)  |  Merge (red + green)\n\n" +
    "You will draw one freehand organoid boundary on the merge. Everything\n" +
    "outside that user-approved boundary becomes pure black in all three panels.\n" +
    "Include dim edge processes inside your boundary—this macro does not use\n" +
    "a threshold or alter fluorescence inside the organoid.\n\n" +
    "It then adds one thick white scale bar to the merge panel. Step 6 files\n" +
    "and raw data are never modified."
);
Dialog.show();

analysisFolder = getDirectory(
    "Step 7 — Select the exact *_FijiAnalysis folder"
);
if (analysisFolder == "")
    exit("No folder was selected. Nothing was changed.");

analysisFolderName = substring(analysisFolder, 0, lengthOf(analysisFolder) - 1);
lastSeparator = lastIndexOf(analysisFolderName, File.separator);
if (lastSeparator >= 0)
    analysisFolderName = substring(analysisFolderName, lastSeparator + 1);
if (!endsWith(analysisFolderName, "_FijiAnalysis"))
    exit("Select the exact folder whose name ends in _FijiAnalysis.");

stepRoot = analysisFolder +
    "02_max_projection_and_figures" + File.separator +
    "06_whole_image_PV_visual_tuning" + File.separator;
cropFolder = stepRoot + "final_crop_panels" + File.separator;
if (!File.exists(cropFolder))
    exit(
        "STEP 6 FINAL CROP OUTPUTS WERE NOT FOUND.\n\n" +
        "Expected:\n" + cropFolder + "\n\n" +
        "Run and accept Step 6 first."
    );

// ----------------------------------------------------------------------------
// 1. FIND THE MOST RECENT COMPLETE STEP 6 RUN
// ----------------------------------------------------------------------------
cropFiles = getFileList(cropFolder);
runPrefix = "final_crop_run_";
latestRun = 0;

for (i = 0; i < lengthOf(cropFiles); i++) {
    cropFile = cropFiles[i];
    cropFileLower = toLowerCase(cropFile);
    if (startsWith(cropFileLower, runPrefix) && endsWith(cropFileLower, "_settings.txt")) {
        runText = substring(cropFileLower, lengthOf(runPrefix), lengthOf(cropFileLower) - lengthOf("_settings.txt"));
        candidateRun = parseInt(runText);
        candidateStem = cropFolder + runPrefix + candidateRun;
        candidateDtom = candidateStem + "_dTomato_red_crop.tif";
        candidatePV = candidateStem + "_PV_green_crop.tif";
        candidateMerge = candidateStem + "_PV_PLUS_dTomato_merge_crop.tif";
        if (candidateRun > latestRun && File.exists(candidateDtom) && File.exists(candidatePV) && File.exists(candidateMerge))
            latestRun = candidateRun;
    }
}

if (latestRun < 1)
    exit(
        "No complete Step 6 crop run was found.\n\n" +
        "The final_crop_panels folder must contain the three TIFF crops and its settings file."
    );

inputStem = cropFolder + runPrefix + latestRun;
dtomPath = inputStem + "_dTomato_red_crop.tif";
pvPath = inputStem + "_PV_green_crop.tif";
mergePath = inputStem + "_PV_PLUS_dTomato_merge_crop.tif";

Dialog.create("Step 7 — confirm saved crop inputs");
Dialog.addMessage(
    "Using Step 6 final crop run " + latestRun + ":\n\n" +
    "dTomato: " + File.getName(dtomPath) + "\n" +
    "PV: " + File.getName(pvPath) + "\n" +
    "Merge: " + File.getName(mergePath) + "\n\n" +
    "New output will be saved separately. These input TIFFs will not change."
);
Dialog.addCheckbox("Yes — use this saved Step 6 run.", false);
Dialog.show();
if (!Dialog.getCheckbox())
    exit("Cancelled before processing. Nothing was changed.");

// ----------------------------------------------------------------------------
// 2. DRAW ONE ORGANOID BOUNDARY ON THE MERGE
// ----------------------------------------------------------------------------
open(mergePath);
mergeSourceTitle = getTitle();
getDimensions(cropW, cropH, cropC, cropZ, cropT);
getPixelSize(scaleUnit, pixelWidth, pixelHeight);
scaleUnitLower = toLowerCase(scaleUnit);
if (pixelWidth <= 0 || pixelHeight <= 0 || scaleUnitLower == "pixel" || scaleUnitLower == "pixels") {
    close();
    exit(
        "This Step 6 crop does not contain usable physical calibration.\n\n" +
        "No output was saved. Recreate the Step 6 crop from calibrated Step 5 images."
    );
}

setTool("freehand");
waitForUser(
    "Step 7 — outline the organoid",
    "Using the freehand selection tool, draw one CLOSED boundary around the organoid\n" +
    "on the merge. Include all dim PV-positive edge structures and neurites you\n" +
    "want to keep. Pixels outside this boundary will become black in every panel.\n\n" +
    "You can redraw the boundary before clicking OK."
);
if (selectionType == -1) {
    close();
    exit("No organoid boundary was detected. Nothing was saved.");
}

getSelectionCoordinates(maskX, maskY);
if (lengthOf(maskX) < 3) {
    close();
    exit("The organoid boundary needs at least three points. Nothing was saved.");
}

Dialog.create("Step 7 — confirm organoid boundary");
Dialog.addMessage(
    "The selected boundary will be applied identically to dTomato, PV, and Merge.\n\n" +
    "Inside the boundary: unchanged display pixels.\n" +
    "Outside the boundary: pure black.\n\n" +
    "This is a presentation mask only; no raw or Step 6 source file changes."
);
Dialog.addCheckbox("Yes — blacken only the area outside this boundary.", false);
Dialog.show();
if (!Dialog.getCheckbox()) {
    close();
    exit("Step 7 cancelled. Nothing was saved.");
}
run("Select None");

// ----------------------------------------------------------------------------
// 3. APPLY THE SAME USER-APPROVED MASK TO THREE WORKING COPIES
// ----------------------------------------------------------------------------
run("Duplicate...", "title=[Step7_merge_masked] duplicate");
mergeMaskedTitle = getTitle();
applyOrganoidMask(mergeMaskedTitle, maskX, maskY);

open(dtomPath);
dtomSourceTitle = getTitle();
run("Duplicate...", "title=[Step7_dTomato_masked] duplicate");
dtomMaskedTitle = getTitle();
applyOrganoidMask(dtomMaskedTitle, maskX, maskY);

open(pvPath);
pvSourceTitle = getTitle();
run("Duplicate...", "title=[Step7_PV_masked] duplicate");
pvMaskedTitle = getTitle();
applyOrganoidMask(pvMaskedTitle, maskX, maskY);

// The three untouched input windows are no longer needed.
selectWindow(mergeSourceTitle); close();
selectWindow(dtomSourceTitle); close();
selectWindow(pvSourceTitle); close();

// ----------------------------------------------------------------------------
// 4. PLACE A WHITE SCALE BAR ON THE MASKED MERGE
// ----------------------------------------------------------------------------
defaultBarLength = minOf(50, floor(cropW * pixelWidth * 0.4));
if (defaultBarLength < 1) defaultBarLength = 1;
defaultBarThickness = 20;
if (defaultBarThickness > floor(cropH / 8))
    defaultBarThickness = maxOf(4, floor(cropH / 8));

Dialog.create("Step 7 — choose scale bar");
Dialog.addMessage(
    "The scale bar will be white and drawn on the Merge panel only.\n\n" +
    "Calibration: " + d2s(pixelWidth, 5) + " " + scaleUnit + " per pixel\n" +
    "You can reposition the bar in the next window. Its requested length and\n" +
    "thickness remain fixed when it is drawn."
);
Dialog.addNumber("Scale bar length", defaultBarLength, 0, 8, scaleUnit);
Dialog.addNumber("Scale bar thickness", defaultBarThickness, 0, 8, "pixels");
Dialog.show();
barLength = Dialog.getNumber();
barThickness = round(Dialog.getNumber());
barPixels = round(barLength / pixelWidth);
if (barPixels < 2 || barPixels >= cropW || barThickness < 1 || barThickness >= cropH)
    exit("The requested scale bar does not fit in this crop. Nothing was saved.");

barMargin = maxOf(30, 2 * barThickness);
defaultBarX = cropW - barPixels - barMargin;
defaultBarY = cropH - barThickness - barMargin;
if (defaultBarX < 0) defaultBarX = 0;
if (defaultBarY < 0) defaultBarY = 0;

selectWindow(mergeMaskedTitle);
makeRectangle(defaultBarX, defaultBarY, barPixels, barThickness);
waitForUser(
    "Step 7 — position scale bar",
    "Drag INSIDE the white selection rectangle to place the scale bar.\n" +
    "Do not resize it: the requested length is retained for the saved bar.\n\n" +
    "Click OK when its position looks right."
);
if (selectionType == -1)
    exit("No scale-bar position was detected. Nothing was saved.");
getSelectionBounds(placedBarX, placedBarY, placedBarW, placedBarH);
if (placedBarX < 0 || placedBarY < 0 || placedBarX + barPixels > cropW || placedBarY + barThickness > cropH)
    exit("Keep the scale bar fully inside the image. Nothing was saved.");

selectWindow(mergeMaskedTitle);
makeRectangle(placedBarX, placedBarY, barPixels, barThickness);
setColor(255, 255, 255);
run("Fill");
run("Select None");
setFont("SansSerif", 22, "bold");
setColor(255, 255, 255);
barLabel = d2s(barLength, 0) + " " + scaleUnit;
labelW = getStringWidth(barLabel);
labelX = placedBarX + (barPixels - labelW) / 2;
labelY = placedBarY - 8;
if (labelY < 22)
    labelY = placedBarY + barThickness + 24;
drawString(barLabel, labelX, labelY);

// ----------------------------------------------------------------------------
// 5. BUILD A CLEAN FULL-RESOLUTION 1 x 3 FINAL PANEL
// ----------------------------------------------------------------------------
headerH = 56;
gap = 12;
panelW = 3 * cropW + 2 * gap;
panelH = headerH + cropH;
newImage("Step7_final_1x3_panel", "RGB black", panelW, panelH, 1);
panelTitle = getTitle();

pasteTile(dtomMaskedTitle, panelTitle, 0, headerH, cropW, cropH);
pasteTile(pvMaskedTitle, panelTitle, cropW + gap, headerH, cropW, cropH);
pasteTile(mergeMaskedTitle, panelTitle, 2 * (cropW + gap), headerH, cropW, cropH);

selectWindow(panelTitle);
drawCenteredLabel("dTomato", 0, cropW, "Red", 26, 36);
drawCenteredLabel("PV", cropW + gap, cropW, "Green", 26, 36);
drawCenteredLabel("Merge", 2 * (cropW + gap), cropW, "White", 26, 36);

// ----------------------------------------------------------------------------
// 6. SAVE ONLY AFTER FINAL USER REVIEW
// ----------------------------------------------------------------------------
finalChoices = newArray("Accept and save final finished panel", "Cancel without saving");
Dialog.create("Step 7 — final panel review");
Dialog.addMessage(
    "Review the masked, full-resolution 1 x 3 panel:\n\n" +
    "dTomato (red) | PV (green) | Merge (red + green + white scale bar)\n\n" +
    "All pixels beyond your organoid boundary are black. Accepting saves new\n" +
    "finished images separately; Step 6 source crops remain unchanged."
);
Dialog.addChoice("Final decision:", finalChoices, "Cancel without saving");
Dialog.show();
if (Dialog.getChoice() == "Cancel without saving") {
    closeStep7Images(dtomMaskedTitle, pvMaskedTitle, mergeMaskedTitle, panelTitle);
    exit("Step 7 cancelled. Nothing was saved.");
}

outputFolder = stepRoot + "final_panel_finish" + File.separator;
File.makeDirectory(outputFolder);
finishRun = 1;
while (File.exists(outputFolder + "final_finish_run_" + finishRun + "_settings.txt"))
    finishRun++;
outputStem = outputFolder + "final_finish_run_" + finishRun;

saveRGB(dtomMaskedTitle, outputStem + "_dTomato_red_masked");
saveRGB(pvMaskedTitle, outputStem + "_PV_green_masked");
saveRGB(mergeMaskedTitle, outputStem + "_PV_PLUS_dTomato_merge_masked_scalebar");
saveRGB(panelTitle, outputStem + "_dTomato_PV_Merge_panel");

// Save the exact user-approved organoid boundary without using ROI Manager.
selectWindow(mergeMaskedTitle);
makeSelection("polygon", maskX, maskY);
saveAs("Selection", outputStem + "_organoid_boundary_ROI.roi");
run("Select None");

settings =
    "STEP 7 — FINAL PANEL FINISH\n" +
    "===========================\n\n" +
    "Step 6 source run: " + latestRun + "\n" +
    "dTomato input: " + dtomPath + "\n" +
    "PV input: " + pvPath + "\n" +
    "Merge input: " + mergePath + "\n\n" +
    "Exterior treatment: all pixels outside the user-approved organoid boundary were set to black.\n" +
    "No thresholding, denoising, background subtraction, or fluorescence adjustment was applied.\n" +
    "Boundary ROI: " + outputStem + "_organoid_boundary_ROI.roi\n\n" +
    "Calibration: " + d2s(pixelWidth, 6) + " " + scaleUnit + " per pixel\n" +
    "White scale bar panel: Merge only\n" +
    "Scale bar length: " + d2s(barLength, 3) + " " + scaleUnit + " (" + barPixels + " pixels)\n" +
    "Scale bar thickness: " + barThickness + " pixels\n" +
    "Scale bar upper-left: X=" + placedBarX + ", Y=" + placedBarY + " pixels\n\n" +
    "All outputs are presentation-only derivatives of Step 6 crops.\n" +
    "Raw data, Steps 3–6 source images, and Step 5 final-review files were not modified.\n";
File.saveString(settings, outputStem + "_settings.txt");

Dialog.create("Step 7 complete");
Dialog.addMessage(
    "Saved final finished panel run " + finishRun + ":\n\n" +
    outputFolder + "\n\n" +
    "Includes masked dTomato/PV/Merge TIFFs and PNGs, the final 1 x 3 panel,\n" +
    "the reusable organoid-boundary ROI, and the exact scale-bar settings."
);
Dialog.show();


// ============================================================================
// FUNCTIONS
// ============================================================================
function applyOrganoidMask(windowTitle, xPoints, yPoints) {
    selectWindow(windowTitle);
    makeSelection("polygon", xPoints, yPoints);
    setBackgroundColor(0, 0, 0);
    run("Clear Outside");
    run("Select None");
}

function pasteTile(sourceTitle, destinationTitle, x, y, w, h) {
    selectWindow(sourceTitle);
    run("Select All");
    run("Copy");
    selectWindow(destinationTitle);
    makeRectangle(x, y, w, h);
    run("Paste");
    run("Select None");
}

function drawCenteredLabel(text, x, w, colorName, fontSize, baselineY) {
    setFont("SansSerif", fontSize, "bold");
    if (colorName == "Red") setColor(255, 0, 0);
    else if (colorName == "Green") setColor(0, 255, 0);
    else setColor(255, 255, 255);
    textW = getStringWidth(text);
    drawString(text, x + (w - textW) / 2, baselineY);
}

function saveRGB(windowTitle, outputStem) {
    selectWindow(windowTitle);
    run("Duplicate...", "title=STEP7_SAVE_TMP");
    run("RGB Color");
    saveAs("Tiff", outputStem + ".tif");
    saveAs("PNG", outputStem + ".png");
    close();
}

function closeStep7Images(dtomTitle, pvTitle, mergeTitle, panelTitle) {
    if (isOpen(dtomTitle)) { selectWindow(dtomTitle); close(); }
    if (isOpen(pvTitle)) { selectWindow(pvTitle); close(); }
    if (isOpen(mergeTitle)) { selectWindow(mergeTitle); close(); }
    if (isOpen(panelTitle)) { selectWindow(panelTitle); close(); }
}
