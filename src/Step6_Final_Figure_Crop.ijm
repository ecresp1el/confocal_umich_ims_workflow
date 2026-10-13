// ============================================================================
// STEP 6 — FINAL WHOLE-IMAGE FIGURE CROP
//
// Creates a presentation-only 1 x 3 final figure from an accepted Step 5 alt
// whole-image final review set:
//     dTomato (red) | PV (green) | PV + dTomato merge
//
// The user sets an initial crop width/height, then drags and rotates ONE native
// Fiji rotated rectangle on the saved merge. The same geometry is straightened
// and applied to all three aligned images. A calibrated, fixed-length scale bar
// is added to the merge tile only after the user drags its placement rectangle.
// Inputs are never modified.
// ============================================================================

requires("1.53");

Dialog.create("Step 6 — final whole-image figure crop");
Dialog.addMessage(
    "Step 6 makes the final 1 x 3 paper figure:\n\n" +
    "dTomato (red)  |  PV (green)  |  PV + dTomato merge\n\n" +
    "You will choose an initial crop width/height, then drag and rotate one\n" +
    "Fiji rotated rectangle on the merge. Its identical geometry is then used\n" +
    "for every panel. A fixed-length scale bar is placed on the\n" +
    "merge panel only.\n\n" +
    "This uses the already approved Step 5 display images and never changes\n" +
    "raw data or final-review source TIFFs."
);
Dialog.show();

analysisFolder = getDirectory(
    "Step 6 — Select the exact *_FijiAnalysis folder"
);
if (analysisFolder == "")
    exit("No folder was selected. Nothing was changed.");

analysisFolderName = substring(analysisFolder, 0, lengthOf(analysisFolder) - 1);
lastSeparator = lastIndexOf(analysisFolderName, File.separator);
if (lastSeparator >= 0)
    analysisFolderName = substring(analysisFolderName, lastSeparator + 1);
if (!endsWith(analysisFolderName, "_FijiAnalysis"))
    exit("Select the exact folder whose name ends in _FijiAnalysis.");

step6Root = analysisFolder +
    "02_max_projection_and_figures" + File.separator +
    "06_whole_image_PV_visual_tuning" + File.separator;
finalReviewFolder = step6Root + "final_figure_review" + File.separator;

if (!File.exists(finalReviewFolder))
    exit(
        "STEP 5 ALT FINAL REVIEW WAS NOT FOUND.\n\n" +
        "Expected:\n" + finalReviewFolder + "\n\n" +
        "Rerun Step5_alt_wholeimage, accept the final figure set, then run Step 6."
    );

// ----------------------------------------------------------------------------
// 1. FIND THE MOST RECENT ACCEPTED STEP 5 ALT FINAL FIGURE RUN
// ----------------------------------------------------------------------------
finalFiles = getFileList(finalReviewFolder);
runPrefix = "whole_image_final_figure_run_";
latestRun = 0;

for (i = 0; i < lengthOf(finalFiles); i++) {
    finalFile = finalFiles[i];
    finalFileLower = toLowerCase(finalFile);
    if (startsWith(finalFileLower, runPrefix) && endsWith(finalFileLower, "_settings.txt")) {
        runText = substring(finalFileLower, lengthOf(runPrefix), lengthOf(finalFileLower) - lengthOf("_settings.txt"));
        candidateRun = parseInt(runText);
        if (candidateRun > latestRun)
            latestRun = candidateRun;
    }
}

if (latestRun < 1)
    exit(
        "No accepted Step 5 alt final figure set was found.\n\n" +
        "The final-review folder exists, but it does not contain a saved final run."
    );

finalStem = finalReviewFolder + runPrefix + latestRun;
dtomPath = finalStem + "_dTomato_red.tif";
pvPath = finalStem + "_PV_green.tif";
mergePath = finalStem + "_PV_PLUS_dTomato.tif";

if (!File.exists(dtomPath) || !File.exists(pvPath) || !File.exists(mergePath))
    exit(
        "The newest saved final run is incomplete.\n\n" +
        "Expected:\n" + dtomPath + "\n" + pvPath + "\n" + mergePath + "\n\n" +
        "No image was changed or saved."
    );

Dialog.create("Step 6 — confirm final figure inputs");
Dialog.addMessage(
    "Using accepted Step 5 alt final figure run " + latestRun + ":\n\n" +
    "dTomato: " + File.getName(dtomPath) + "\n" +
    "PV: " + File.getName(pvPath) + "\n" +
    "Merge: " + File.getName(mergePath) + "\n\n" +
    "The merge is red + green only; DAPI is intentionally not included in this final 1 x 3 figure."
);
Dialog.addCheckbox("Yes — use this saved final-review run.", false);
Dialog.show();
if (!Dialog.getCheckbox())
    exit("Cancelled before processing. Nothing was changed.");

// ----------------------------------------------------------------------------
// 2. SIZE, DRAG, AND ROTATE ONE RECTANGULAR CROP ON THE SAVED MERGE
// ----------------------------------------------------------------------------
open(mergePath);
mergeSourceTitle = getTitle();
getDimensions(sourceW, sourceH, sourceC, sourceZ, sourceT);

getPixelSize(scaleUnit, pixelWidth, pixelHeight);
scaleUnitLower = toLowerCase(scaleUnit);
if (pixelWidth <= 0 || pixelHeight <= 0 || scaleUnitLower == "pixel" || scaleUnitLower == "pixels")
    exit(
        "This saved final-review TIFF does not contain usable physical calibration.\n\n" +
        "No image was saved. Recreate the Step 5 final review from calibrated Step 3 images."
    );

defaultCropWidth = minOf(200, floor(sourceW * pixelWidth * 0.8));
defaultCropHeight = minOf(200, floor(sourceH * pixelHeight * 0.8));
if (defaultCropWidth < 1) defaultCropWidth = 1;
if (defaultCropHeight < 1) defaultCropHeight = 1;

Dialog.create("Step 6 — choose initial crop size");
Dialog.addMessage(
    "Set the initial physical crop size. You will then drag and rotate it directly\n" +
    "on the merge—no X/Y coordinates are needed.\n\n" +
    "Image size: " + sourceW + " × " + sourceH + " pixels\n" +
    "Calibration: " + d2s(pixelWidth, 5) + " " + scaleUnit + " per pixel\n\n" +
    "The final crop remains a true rotated rectangle and is straightened consistently\n" +
    "for dTomato, PV, and Merge."
);
Dialog.addNumber("Initial crop width", defaultCropWidth, 0, 8, scaleUnit);
Dialog.addNumber("Initial crop height", defaultCropHeight, 0, 8, scaleUnit);
Dialog.show();
requestedCropWidth = Dialog.getNumber();
requestedCropHeight = Dialog.getNumber();
roiLengthPixels = round(requestedCropWidth / pixelWidth);
roiWidthPixels = round(requestedCropHeight / pixelHeight);
if (roiLengthPixels < 2 || roiWidthPixels < 2 || roiLengthPixels > sourceW - 2 || roiWidthPixels > sourceH - 2)
    exit("The requested initial crop size does not fit in this image. Nothing was saved.");

defaultX1 = round((sourceW - roiLengthPixels) / 2);
defaultY1 = round(sourceH / 2);
defaultX2 = defaultX1 + roiLengthPixels;
defaultY2 = defaultY1;
selectWindow(mergeSourceTitle);
setTool("rotrect");
makeRotatedRectangle(defaultX1, defaultY1, defaultX2, defaultY2, roiWidthPixels);
waitForUser(
    "Step 6 — position and rotate the final crop",
    "Drag inside the rectangle to move it. Fiji does not use a curved-arrow handle here:\n" +
    "drag either small square centered on a SHORT end to rotate/extend it; drag a\n" +
    "small square centered on a LONG side to change its thickness.\n\n" +
    "This one ROI will be applied identically to dTomato, PV, and Merge.\n" +
    "Click OK only when the crop looks right."
);

if (selectionType == -1)
    exit("No rotated crop was detected. Nothing was saved.");

// A RotatedRectRoi supplies four corners in this order:
// start+perpendicular, end+perpendicular, end-perpendicular, start-perpendicular.
// Reconstructing its centreline and width lets us apply the exact same rotated
// geometry to each aligned source image.
getSelectionCoordinates(roiXPoints, roiYPoints);
if (lengthOf(roiXPoints) != 4) {
    selectWindow(mergeSourceTitle);
    close();
    exit("Use Fiji's Rotated Rectangle tool for the final crop. Nothing was saved.");
}
for (p = 0; p < 4; p++) {
    if (roiXPoints[p] < 0 || roiYPoints[p] < 0 || roiXPoints[p] >= sourceW || roiYPoints[p] >= sourceH) {
        selectWindow(mergeSourceTitle);
        close();
        exit("Keep the full rotated rectangle inside the image bounds. Nothing was saved.");
    }
}
roiX1 = (roiXPoints[0] + roiXPoints[3]) / 2;
roiY1 = (roiYPoints[0] + roiYPoints[3]) / 2;
roiX2 = (roiXPoints[1] + roiXPoints[2]) / 2;
roiY2 = (roiYPoints[1] + roiYPoints[2]) / 2;
roiFinalWidthPixels = sqrt(pow(roiXPoints[0] - roiXPoints[3], 2) + pow(roiYPoints[0] - roiYPoints[3], 2));
roiFinalLengthPixels = sqrt(pow(roiX2 - roiX1, 2) + pow(roiY2 - roiY1, 2));
if (roiFinalLengthPixels < 2 || roiFinalWidthPixels < 2) {
    selectWindow(mergeSourceTitle);
    close();
    exit("The rotated crop is too small. Nothing was saved.");
}

Dialog.create("Step 6 — confirm rotated crop");
Dialog.addMessage(
    "Final rotated crop\n\n" +
    "Length: " + d2s(roiFinalLengthPixels * pixelWidth, 2) + " " + scaleUnit + "\n" +
    "Width: " + d2s(roiFinalWidthPixels * pixelHeight, 2) + " " + scaleUnit + "\n\n" +
    "This exact angle, position, and size will be straightened identically for all three panels."
);
Dialog.addCheckbox("Yes — use this rotated crop.", false);
Dialog.show();
if (!Dialog.getCheckbox()) {
    selectWindow(mergeSourceTitle);
    close();
    exit("Step 6 cancelled. Nothing was saved.");
}

// ----------------------------------------------------------------------------
// 3. MAKE THREE IDENTICAL CROPS FROM THE ACCEPTED DISPLAY IMAGES
// ----------------------------------------------------------------------------
open(dtomPath);
dtomSourceTitle = getTitle();
open(pvPath);
pvSourceTitle = getTitle();

dtomCropTitle = makeRotatedCrop(dtomSourceTitle, roiX1, roiY1, roiX2, roiY2, roiFinalWidthPixels, "Step6_dTomato_crop");
pvCropTitle = makeRotatedCrop(pvSourceTitle, roiX1, roiY1, roiX2, roiY2, roiFinalWidthPixels, "Step6_PV_crop");
mergeCropTitle = makeRotatedCrop(mergeSourceTitle, roiX1, roiY1, roiX2, roiY2, roiFinalWidthPixels, "Step6_merge_crop");
selectWindow(mergeCropTitle);
getDimensions(cropW, cropH, cropC, cropZ, cropT);

// Close only full-field source windows. Crops remain open for review/output.
selectWindow(dtomSourceTitle); close();
selectWindow(pvSourceTitle); close();
selectWindow(mergeSourceTitle); close();

// ----------------------------------------------------------------------------
// 4. CREATE A FIXED-LENGTH, USER-MOVEABLE SCALE BAR ON THE MERGE CROP
// ----------------------------------------------------------------------------
Dialog.create("Step 6 — choose scale-bar size");
Dialog.addMessage(
    "The image calibration is " + d2s(pixelWidth, 5) + " " + scaleUnit + " per pixel.\n\n" +
    "A thick WHITE 50 " + scaleUnit + " bar is the default for a cellular crop.\n" +
    "Use 25 for a tight crop or 100 for a broad field. You will drag the exact\n" +
    "fixed-length bar to its final position on the merge panel next."
);
Dialog.addNumber("Scale-bar length", 50, 0, 8, scaleUnit);
Dialog.addNumber("White scale-bar thickness", 20, 0, 8, "pixels");
Dialog.show();
barLength = Dialog.getNumber();
barHeight = Dialog.getNumber();
if (barLength <= 0 || barHeight < 1)
    exit("Scale-bar length and thickness must be positive. Nothing was saved.");

barPixels = round(barLength / pixelWidth);
if (barPixels < 2 || barPixels > cropW - 4)
    exit(
        "This scale bar will not fit in the selected crop.\n\n" +
        "Choose a shorter bar or a wider crop. Nothing was saved."
    );
if (barHeight > cropH - 4)
    exit("The chosen scale-bar thickness will not fit in the crop. Nothing was saved.");

barMargin = maxOf(20, round(cropW * 0.03));
defaultBarX = cropW - barPixels - barMargin;
defaultBarY = cropH - barHeight - barMargin;
if (defaultBarX < 2) defaultBarX = 2;
if (defaultBarY < 2) defaultBarY = 2;

barAccepted = 0;
while (barAccepted == 0) {
    selectWindow(mergeCropTitle);
    makeRectangle(defaultBarX, defaultBarY, barPixels, barHeight);
    setTool("rectangle");
    waitForUser(
        "Step 6 — position the scale bar",
        "The yellow rectangle is a " + barLength + " " + scaleUnit + " scale bar.\n\n" +
        "Drag it from inside the rectangle to move it. Do not resize it.\n" +
        "Place it where it is legible without covering an important structure, then click OK."
    );

    if (selectionType != 0) {
        Dialog.create("Scale-bar placement required");
        Dialog.addMessage("Keep the scale bar as a rectangular selection and try again.");
    } else {
        getSelectionBounds(barX, barY, placedBarW, placedBarH);
        barWidthDifference = placedBarW - barPixels;
        barHeightDifference = placedBarH - barHeight;
        if (barWidthDifference > 1 || barWidthDifference < -1 || barHeightDifference > 1 || barHeightDifference < -1) {
            Dialog.create("Scale-bar length changed");
            Dialog.addMessage(
                "The bar must stay exactly " + barLength + " " + scaleUnit + ".\n\n" +
                "Move it from inside the rectangle rather than dragging its handles. A fresh fixed-length bar will be shown."
            );
            Dialog.show();
        } else if (barX < 0 || barY < 0 || barX + placedBarW > cropW || barY + placedBarH > cropH) {
            Dialog.create("Scale bar outside crop");
            Dialog.addMessage("Place the complete scale bar inside the merge crop.");
            Dialog.show();
        } else {
            // Build a temporary, baked preview for approval. The no-scale merge crop is retained.
            selectWindow(mergeCropTitle);
            run("Duplicate...", "title=Step6_merge_scale_preview");
            scalePreviewTitle = getTitle();
            setColor(255, 255, 255);
            fillRect(barX, barY, placedBarW, placedBarH);
            setFont("SansSerif", maxOf(16, round(barHeight * 2.2)), "bold");
            labelText = d2s(barLength, 0) + " " + scaleUnit;
            labelX = barX + (placedBarW - getStringWidth(labelText)) / 2;
            labelY = barY - maxOf(8, round(barHeight * 0.8));
            if (labelY < 16) labelY = barY + placedBarH + maxOf(18, round(barHeight * 2.4));
            drawString(labelText, labelX, labelY);

            run("Tile");
            barChoices = newArray("Use this scale-bar placement", "Move scale bar again", "Cancel without saving");
            Dialog.create("Step 6 — review scale bar");
            Dialog.addMessage(
                "The white scale bar and its label are previewed on the merge crop.\n\n" +
                "Length: " + barLength + " " + scaleUnit + "\n" +
                "Position: X=" + barX + ", Y=" + barY + " pixels\n\n" +
                "It will appear only on the third (Merge) panel."
            );
            Dialog.addChoice("Next action:", barChoices, "Use this scale-bar placement");
            Dialog.show();
            barDecision = Dialog.getChoice();

            if (barDecision == "Use this scale-bar placement")
                barAccepted = 1;
            else {
                selectWindow(scalePreviewTitle);
                close();
                if (barDecision == "Cancel without saving") {
                    closeStep6Crops(dtomCropTitle, pvCropTitle, mergeCropTitle);
                    exit("Step 6 cancelled. Nothing was saved.");
                }
            }
        }
    }
}

// ----------------------------------------------------------------------------
// 5. CREATE FULL-RESOLUTION HORIZONTAL 1 x 3 FIGURE
// ----------------------------------------------------------------------------
headerH = 56;
gap = 12;
panelW = 3 * cropW + 2 * gap;
panelH = headerH + cropH;
newImage("Step6_final_1x3_panel", "RGB black", panelW, panelH, 1);
panelTitle = getTitle();

pasteTile(dtomCropTitle, panelTitle, 0, headerH, cropW, cropH);
pasteTile(pvCropTitle, panelTitle, cropW + gap, headerH, cropW, cropH);
pasteTile(scalePreviewTitle, panelTitle, 2 * (cropW + gap), headerH, cropW, cropH);

selectWindow(panelTitle);
drawCenteredLabel("dTomato", 0, cropW, "Red", 26, 36);
drawCenteredLabel("PV", cropW + gap, cropW, "Green", 26, 36);
drawCenteredLabel("Merge", 2 * (cropW + gap), cropW, "White", 26, 36);

// ----------------------------------------------------------------------------
// 6. SAVE A REPRODUCIBLE FINAL-FIGURE RUN ONLY AFTER USER APPROVAL
// ----------------------------------------------------------------------------
finalChoices = newArray("Accept and save final 1 x 3 figure", "Cancel without saving");
Dialog.create("Step 6 — final figure review");
Dialog.addMessage(
    "Review the final full-resolution panel:\n\n" +
    "dTomato (red) | PV (green) | Merge (red + green with scale bar)\n\n" +
    "Accepting saves individual crops, the scale-bar merge crop, a single 1 x 3 TIFF/PNG panel,\n" +
    "the rectangular ROI, and a settings record."
);
Dialog.addChoice("Final decision:", finalChoices, "Cancel without saving");
Dialog.show();
if (Dialog.getChoice() == "Cancel without saving") {
    closeStep6Crops(dtomCropTitle, pvCropTitle, mergeCropTitle);
    if (isOpen(scalePreviewTitle)) { selectWindow(scalePreviewTitle); close(); }
    if (isOpen(panelTitle)) { selectWindow(panelTitle); close(); }
    exit("Step 6 cancelled. Nothing was saved.");
}

outputFolder = step6Root + "final_crop_panels" + File.separator;
File.makeDirectory(outputFolder);
finalCropRun = 1;
while (File.exists(outputFolder + "final_crop_run_" + finalCropRun + "_settings.txt"))
    finalCropRun++;
outputStem = outputFolder + "final_crop_run_" + finalCropRun;

saveRGB(dtomCropTitle, outputStem + "_dTomato_red_crop");
saveRGB(pvCropTitle, outputStem + "_PV_green_crop");
saveRGB(mergeCropTitle, outputStem + "_PV_PLUS_dTomato_crop_no_scale_bar");
saveRGB(scalePreviewTitle, outputStem + "_PV_PLUS_dTomato_crop_with_scale_bar");
saveRGB(panelTitle, outputStem + "_dTomato_PV_Merge_panel");

// Save the exact full-field rotated ROI without changing the ROI Manager.
open(mergePath);
roiSaveSource = getTitle();
makeRotatedRectangle(roiX1, roiY1, roiX2, roiY2, roiFinalWidthPixels);
saveAs("Selection", outputStem + "_crop_ROI.roi");
close();

settings =
    "STEP 6 — FINAL WHOLE-IMAGE FIGURE CROP\n" +
    "=========================================\n\n" +
    "Step 5 alt source run: " + latestRun + "\n" +
    "dTomato input: " + dtomPath + "\n" +
    "PV input: " + pvPath + "\n" +
    "Merge input: " + mergePath + "\n\n" +
    "Full-field rotated rectangle (pixels)\n" +
    "Centreline start: X=" + d2s(roiX1, 3) + ", Y=" + d2s(roiY1, 3) + "\n" +
    "Centreline end: X=" + d2s(roiX2, 3) + ", Y=" + d2s(roiY2, 3) + "\n" +
    "Length: " + d2s(roiFinalLengthPixels, 3) + " pixels\n" +
    "Width: " + d2s(roiFinalWidthPixels, 3) + " pixels\n\n" +
    "Calibration: " + d2s(pixelWidth, 6) + " " + scaleUnit + " per pixel\n" +
    "Scale-bar length: " + d2s(barLength, 0) + " " + scaleUnit + "\n" +
    "Scale-bar length: " + barPixels + " pixels\n" +
    "Scale-bar thickness: " + barHeight + " pixels\n" +
    "Scale-bar crop position: X=" + barX + ", Y=" + barY + "\n\n" +
    "All outputs are presentation-only crops from accepted Step 5 display images.\n" +
    "Raw data, Step 3 outputs, and Step 5 final-review source files were not modified.\n";
File.saveString(settings, outputStem + "_settings.txt");

Dialog.create("Step 6 complete");
Dialog.addMessage(
    "Saved final full-resolution figure run " + finalCropRun + ":\n\n" +
    outputFolder + "\n\n" +
    "Includes dTomato, PV, no-scale merge, scale-bar merge, 1 x 3 TIFF/PNG panel,\n" +
    "the reusable rectangular ROI, and exact crop/scale-bar settings."
);
Dialog.show();


// ============================================================================
// FUNCTIONS
// ============================================================================
function makeRotatedCrop(sourceTitle, x1, y1, x2, y2, rectWidth, newTitle) {
    selectWindow(sourceTitle);
    makeRotatedRectangle(x1, y1, x2, y2, rectWidth);
    run("Duplicate...", "title=[" + newTitle + "] duplicate");
    return getTitle();
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
    run("Duplicate...", "title=STEP6_SAVE_TMP");
    run("RGB Color");
    saveAs("Tiff", outputStem + ".tif");
    saveAs("PNG", outputStem + ".png");
    close();
}

function closeStep6Crops(dtomTitle, pvTitle, mergeTitle) {
    if (isOpen(dtomTitle)) { selectWindow(dtomTitle); close(); }
    if (isOpen(pvTitle)) { selectWindow(pvTitle); close(); }
    if (isOpen(mergeTitle)) { selectWindow(mergeTitle); close(); }
}
