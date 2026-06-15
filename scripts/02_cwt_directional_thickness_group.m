```matlab
clc;
clear;
close all;

%% ============================================================
% Directional Chest Wall Thickness Calculation
%
% Project: Moroccan Digital Voxelized Thoracic Phantoms
% Author: Oussama Aabi
%
% Description:
% This script calculates directional thoracic thickness from voxelized
% thoracic labelmaps.
%
% Method:
%   - Detect all axial slices containing lungs
%   - Remove the first inferior lung slices
%   - Calculate anterior/posterior thickness on selected slices
%   - Calculate left/right thickness on selected slices
%   - Compare the mean thickness with a reference CWT value
%
% Default reference:
%   CWT = 28.7 +/- 4.2 mm
%
% Required Excel file:
%   data/spacing_patients.xlsx
%
% Expected local labelmap folders:
%   patient_H/labelmaps_H/
%   patient_F/labelmaps_F/
%   patient_E/labelmaps_E/
%
% Outputs:
%   - Excel files in results/tables/cwt_directional/
%   - PNG and FIG figures in results/figures/cwt_directional/
%
% Important:
% NRRD labelmaps are used locally and should not be uploaded to GitHub.
%% ============================================================

%% ===================== PROJECT FOLDER SELECTION =====================

projectFolder = uigetdir(pwd, 'Select the project folder');

if projectFolder == 0
    error('No project folder selected.');
end

excelFile = fullfile(projectFolder, 'data', 'spacing_patients.xlsx');

if ~isfile(excelFile)
    error('Excel file not found: %s', excelFile);
end

tablesFolder = fullfile(projectFolder, 'results', 'tables', 'cwt_directional');
figuresFolder = fullfile(projectFolder, 'results', 'figures', 'cwt_directional');

if ~exist(tablesFolder, 'dir')
    mkdir(tablesFolder);
end

if ~exist(figuresFolder, 'dir')
    mkdir(figuresFolder);
end

if exist('nrrdread', 'file') ~= 2
    error('The function nrrdread was not found. Please add an NRRD reader to the MATLAB path.');
end

%% ===================== GROUP SELECTION =====================

fprintf('\n===== GROUP SELECTION =====\n');
fprintf('H : Male\n');
fprintf('F : Female\n');
fprintf('E : Child\n');

groupCode = upper(strtrim(input('Select the group to process (H/F/E): ', 's')));

if ~ismember(groupCode, {'H','F','E'})
    error('Invalid group. Please select only H, F, or E.');
end

switch groupCode
    case 'H'
        groupName = 'Male';
        sheetName = 'Homme';
        defaultPatientFolder = fullfile(projectFolder, 'patient_H');
        defaultLabelmapFolder = fullfile(defaultPatientFolder, 'labelmaps_H');

    case 'F'
        groupName = 'Female';
        sheetName = 'Femme';
        defaultPatientFolder = fullfile(projectFolder, 'patient_F');
        defaultLabelmapFolder = fullfile(defaultPatientFolder, 'labelmaps_F');

    case 'E'
        groupName = 'Child';
        sheetName = 'Enfant';
        defaultPatientFolder = fullfile(projectFolder, 'patient_E');
        defaultLabelmapFolder = fullfile(defaultPatientFolder, 'labelmaps_E');
end

labelmapFolder = defaultLabelmapFolder;
patientFolder = defaultPatientFolder;

if ~exist(labelmapFolder, 'dir')
    warning('Default labelmap folder not found: %s', labelmapFolder);

    selectedFolder = uigetdir(projectFolder, ['Select labelmap folder for group ', groupCode]);

    if selectedFolder == 0
        error('No labelmap folder selected.');
    end

    labelmapFolder = selectedFolder;
    patientFolder = fileparts(labelmapFolder);
end

%% ===================== READ EXCEL FILE =====================

try
    patientTable = readtable(excelFile, 'Sheet', sheetName, 'VariableNamingRule', 'preserve');
catch
    if strcmp(groupCode, 'F')
        sheetName = 'Femmes';
        patientTable = readtable(excelFile, 'Sheet', sheetName, 'VariableNamingRule', 'preserve');
    else
        error('Unable to read Excel sheet: %s', sheetName);
    end
end

patientColumn = getExistingColumn(patientTable, {'patient', 'id_patients', 'id_patient', 'Patient'});
fileColumn = getExistingColumn(patientTable, {'file_nrrd', 'file_labelmap', 'File_NRRD', 'File_Labelmap'});
spacingXColumn = getExistingColumn(patientTable, {'spacing_x', 'Spacing_X', 'Spacing_X_mm'});
spacingYColumn = getExistingColumn(patientTable, {'spacing_y', 'Spacing_Y', 'Spacing_Y_mm'});
spacingZColumn = getExistingColumn(patientTable, {'spacing_z', 'Spacing_Z', 'Spacing_Z_mm'});

patientIDs = string(patientTable.(patientColumn));
fileNames = string(patientTable.(fileColumn));
spacingX = patientTable.(spacingXColumn);
spacingY = patientTable.(spacingYColumn);
spacingZ = patientTable.(spacingZColumn);

validRows = startsWith(upper(patientIDs), groupCode);

if ~any(validRows)
    error('No patient IDs starting with %s were found in the Excel sheet.', groupCode);
end

patientIDs = patientIDs(validRows);
fileNames = fileNames(validRows);
spacingX = spacingX(validRows);
spacingY = spacingY(validRows);
spacingZ = spacingZ(validRows);

numberOfPatients = numel(patientIDs);

fprintf('\nGroup selected: %s\n', groupName);
fprintf('Number of patients found: %d\n', numberOfPatients);

%% ===================== PARAMETERS =====================

referenceCWT_mm = 28.7;
referenceSD_mm = 4.2;

numberOfInferiorSlicesToSkip = 10;
numberOfSlicesAP = 30;
numberOfSlicesLR = 15;

minDistanceMM = 0;
maxDistanceMM = 45;

percentileValue = 25;

%% ===================== INITIALIZATION =====================

lungLabelDetected = NaN(numberOfPatients,1);
bodyLabelDetected = NaN(numberOfPatients,1);

numberOfLungSlices = NaN(numberOfPatients,1);
firstLungSlice = NaN(numberOfPatients,1);
lastLungSlice = NaN(numberOfPatients,1);

numberOfUsedAPSlices = NaN(numberOfPatients,1);
numberOfUsedLRSlices = NaN(numberOfPatients,1);

anteriorMeanMM = NaN(numberOfPatients,1);
posteriorMeanMM = NaN(numberOfPatients,1);
leftMeanMM = NaN(numberOfPatients,1);
rightMeanMM = NaN(numberOfPatients,1);

anteriorStdMM = NaN(numberOfPatients,1);
posteriorStdMM = NaN(numberOfPatients,1);
leftStdMM = NaN(numberOfPatients,1);
rightStdMM = NaN(numberOfPatients,1);

meanDirectionalThicknessMM = NaN(numberOfPatients,1);
stdFourDirectionsMM = NaN(numberOfPatients,1);

minThicknessMM = NaN(numberOfPatients,1);
maxThicknessMM = NaN(numberOfPatients,1);

distanceToReferenceCWTMM = NaN(numberOfPatients,1);
withinReferenceInterval = false(numberOfPatients,1);

detailsAP = table();
detailsLR = table();

%% ===================== PATIENT LOOP =====================

for i = 1:numberOfPatients

    patientID = patientIDs(i);
    labelmapFile = fileNames(i);

    nrrdPath = fullfile(labelmapFolder, labelmapFile);

    if ~isfile(nrrdPath)
        nrrdPath = fullfile(labelmapFolder, patientID + ".nrrd");
    end

    if ~isfile(nrrdPath)
        files = dir(fullfile(patientFolder, '**', patientID + ".nrrd"));
        if ~isempty(files)
            nrrdPath = fullfile(files(1).folder, files(1).name);
        else
            warning('NRRD file not found for patient %s. Skipping.', patientID);
            continue;
        end
    end

    fprintf('\n==============================\n');
    fprintf('Patient: %s\n', patientID);
    fprintf('File: %s\n', nrrdPath);

    labelmap = nrrdread(nrrdPath);
    labelmap = squeeze(labelmap);

    %% ===================== LABEL DETECTION =====================

    labels = unique(labelmap(:));
    labels = labels(labels > 0);

    if numel(labels) < 2
        warning('Less than two labels found for patient %s. Skipping.', patientID);
        continue;
    end

    if groupCode == "F"
        lungLabel = 1;
        bodyLabel = 2;
    else
        counts = zeros(numel(labels),1);

        for k = 1:numel(labels)
            counts(k) = nnz(labelmap == labels(k));
        end

        [~, idxMin] = min(counts);
        [~, idxMax] = max(counts);

        lungLabel = labels(idxMin);
        bodyLabel = labels(idxMax);
    end

    lungLabelDetected(i) = lungLabel;
    bodyLabelDetected(i) = bodyLabel;

    fprintf('Detected lung label: %g\n', lungLabel);
    fprintf('Detected body label: %g\n', bodyLabel);

    lungMask = (labelmap == lungLabel);
    bodyMask = (labelmap == bodyLabel);

    %% ===================== LUNG SLICE DETECTION =====================

    lungSlices = squeeze(any(any(lungMask, 1), 2));
    sliceIndices = find(lungSlices);

    numberOfLungSlices(i) = numel(sliceIndices);

    if isempty(sliceIndices)
        warning('No lung slice found for patient %s. Skipping.', patientID);
        continue;
    end

    firstLungSlice(i) = sliceIndices(1);
    lastLungSlice(i) = sliceIndices(end);

    fprintf('Total lung slices: %d\n', numel(sliceIndices));
    fprintf('First lung slice: %d | Last lung slice: %d\n', sliceIndices(1), sliceIndices(end));

    %% ===================== SLICE SELECTION =====================

    startIndex = numberOfInferiorSlicesToSkip + 1;

    if numel(sliceIndices) < startIndex
        warning('Not enough lung slices after inferior slice removal for patient %s. Skipping.', patientID);
        continue;
    end

    availableSlices = sliceIndices(startIndex:end);

    if numel(availableSlices) >= numberOfSlicesAP
        selectedSlicesAP = availableSlices(1:numberOfSlicesAP);
    else
        selectedSlicesAP = availableSlices;
    end

    if numel(availableSlices) >= numberOfSlicesLR
        selectedSlicesLR = availableSlices(1:numberOfSlicesLR);
    else
        selectedSlicesLR = availableSlices;
    end

    fprintf('AP slices used after skipping inferior slices: ');
    fprintf('%d ', selectedSlicesAP);
    fprintf('\n');

    fprintf('LR slices used after skipping inferior slices: ');
    fprintf('%d ', selectedSlicesLR);
    fprintf('\n');

    %% ===================== ANTERIOR / POSTERIOR THICKNESS =====================

    anteriorValues = [];
    posteriorValues = [];
    sliceValuesAP = [];

    for s = selectedSlicesAP'

        lung2D = lungMask(:,:,s);
        body2D = bodyMask(:,:,s);

        if ~any(lung2D(:)) || ~any(body2D(:))
            continue;
        end

        [anteriorMM, posteriorMM] = calculateAnteriorPosteriorThickness( ...
            lung2D, body2D, spacingY(i), ...
            minDistanceMM, maxDistanceMM, percentileValue);

        if ~isnan(anteriorMM)
            anteriorValues(end+1,1) = anteriorMM;
        end

        if ~isnan(posteriorMM)
            posteriorValues(end+1,1) = posteriorMM;
        end

        if ~isnan(anteriorMM) || ~isnan(posteriorMM)
            sliceValuesAP(end+1,1) = s;
        end
    end

    numberOfUsedAPSlices(i) = numel(sliceValuesAP);

    tempAP = table( ...
        repmat(patientID, numel(sliceValuesAP), 1), ...
        repmat(labelmapFile, numel(sliceValuesAP), 1), ...
        sliceValuesAP, ...
        padToLength(anteriorValues, numel(sliceValuesAP)), ...
        padToLength(posteriorValues, numel(sliceValuesAP)), ...
        'VariableNames', {'Patient','File_NRRD','Slice_Index','Anterior_mm','Posterior_mm'});

    detailsAP = [detailsAP; tempAP];

    %% ===================== LEFT / RIGHT THICKNESS =====================

    leftValues = [];
    rightValues = [];
    sliceValuesLR = [];

    for s = selectedSlicesLR'

        lung2D = lungMask(:,:,s);
        body2D = bodyMask(:,:,s);

        if ~any(lung2D(:)) || ~any(body2D(:))
            continue;
        end

        [leftMM, rightMM] = calculateLeftRightThickness( ...
            lung2D, body2D, spacingX(i), ...
            minDistanceMM, maxDistanceMM, percentileValue);

        if ~isnan(leftMM)
            leftValues(end+1,1) = leftMM;
        end

        if ~isnan(rightMM)
            rightValues(end+1,1) = rightMM;
        end

        if ~isnan(leftMM) || ~isnan(rightMM)
            sliceValuesLR(end+1,1) = s;
        end
    end

    numberOfUsedLRSlices(i) = numel(sliceValuesLR);

    tempLR = table( ...
        repmat(patientID, numel(sliceValuesLR), 1), ...
        repmat(labelmapFile, numel(sliceValuesLR), 1), ...
        sliceValuesLR, ...
        padToLength(leftValues, numel(sliceValuesLR)), ...
        padToLength(rightValues, numel(sliceValuesLR)), ...
        'VariableNames', {'Patient','File_NRRD','Slice_Index','Left_mm','Right_mm'});

    detailsLR = [detailsLR; tempLR];

    %% ===================== PATIENT SUMMARY =====================

    anteriorMeanMM(i) = mean(anteriorValues, 'omitnan');
    posteriorMeanMM(i) = mean(posteriorValues, 'omitnan');
    leftMeanMM(i) = mean(leftValues, 'omitnan');
    rightMeanMM(i) = mean(rightValues, 'omitnan');

    anteriorStdMM(i) = std(anteriorValues, 'omitnan');
    posteriorStdMM(i) = std(posteriorValues, 'omitnan');
    leftStdMM(i) = std(leftValues, 'omitnan');
    rightStdMM(i) = std(rightValues, 'omitnan');

    fourDirections = [
        anteriorMeanMM(i), ...
        posteriorMeanMM(i), ...
        leftMeanMM(i), ...
        rightMeanMM(i)
    ];

    meanDirectionalThicknessMM(i) = mean(fourDirections, 'omitnan');
    stdFourDirectionsMM(i) = std(fourDirections, 'omitnan');

    allThicknessValues = [
        anteriorValues;
        posteriorValues;
        leftValues;
        rightValues
    ];

    if ~isempty(allThicknessValues)
        minThicknessMM(i) = min(allThicknessValues);
        maxThicknessMM(i) = max(allThicknessValues);
    end

    distanceToReferenceCWTMM(i) = abs(meanDirectionalThicknessMM(i) - referenceCWT_mm);

    withinReferenceInterval(i) = meanDirectionalThicknessMM(i) >= (referenceCWT_mm - referenceSD_mm) && ...
                                 meanDirectionalThicknessMM(i) <= (referenceCWT_mm + referenceSD_mm);

    fprintf('Anterior mean   = %.2f mm\n', anteriorMeanMM(i));
    fprintf('Posterior mean  = %.2f mm\n', posteriorMeanMM(i));
    fprintf('Left mean       = %.2f mm\n', leftMeanMM(i));
    fprintf('Right mean      = %.2f mm\n', rightMeanMM(i));
    fprintf('Global mean directional thickness = %.2f mm\n', meanDirectionalThicknessMM(i));
    fprintf('Distance to reference CWT %.2f mm = %.2f mm\n', referenceCWT_mm, distanceToReferenceCWTMM(i));
end

%% ===================== RESULT TABLES =====================

resultsThickness = table(patientIDs, fileNames, ...
    spacingX, spacingY, spacingZ, ...
    lungLabelDetected, bodyLabelDetected, ...
    numberOfLungSlices, firstLungSlice, lastLungSlice, ...
    numberOfUsedAPSlices, numberOfUsedLRSlices, ...
    anteriorMeanMM, posteriorMeanMM, leftMeanMM, rightMeanMM, ...
    anteriorStdMM, posteriorStdMM, leftStdMM, rightStdMM, ...
    meanDirectionalThicknessMM, stdFourDirectionsMM, ...
    minThicknessMM, maxThicknessMM, ...
    distanceToReferenceCWTMM, withinReferenceInterval, ...
    'VariableNames', {'Patient','File_NRRD', ...
    'Spacing_X_mm','Spacing_Y_mm','Spacing_Z_mm', ...
    'Lung_Label','Body_Label', ...
    'Number_Of_Lung_Slices','First_Lung_Slice','Last_Lung_Slice', ...
    'Number_Of_AP_Slices_Used','Number_Of_LR_Slices_Used', ...
    'Anterior_Mean_mm','Posterior_Mean_mm','Left_Mean_mm','Right_Mean_mm', ...
    'Anterior_Std_mm','Posterior_Std_mm','Left_Std_mm','Right_Std_mm', ...
    'Mean_Directional_Thickness_mm','Std_Four_Directions_mm', ...
    'Min_Thickness_mm','Max_Thickness_mm', ...
    'Distance_To_Reference_CWT_mm','Within_Reference_Interval'});

validSummaryRows = ~isnan(resultsThickness.Mean_Directional_Thickness_mm);

if ~any(validSummaryRows)
    error('No valid directional thickness results were calculated.');
end

validThicknessValues = resultsThickness.Mean_Directional_Thickness_mm(validSummaryRows);
validRowIndices = find(validSummaryRows);

groupMeanMM = mean(validThicknessValues, 'omitnan');
groupStdMM = std(validThicknessValues, 'omitnan');
groupMedianMM = median(validThicknessValues, 'omitnan');

[minGroupMM, localMinIndex] = min(validThicknessValues);
[maxGroupMM, localMaxIndex] = max(validThicknessValues);

indexMin = validRowIndices(localMinIndex);
indexMax = validRowIndices(localMaxIndex);

distanceToGroupMeanMM = abs(resultsThickness.Mean_Directional_Thickness_mm - groupMeanMM);
resultsThickness.Distance_To_Group_Mean_mm = distanceToGroupMeanMM;

validDistanceToMean = distanceToGroupMeanMM(validSummaryRows);
[minimumDistanceToMean, localClosestMeanIndex] = min(validDistanceToMean);

validDistanceToReference = resultsThickness.Distance_To_Reference_CWT_mm(validSummaryRows);
[minimumDistanceToReference, localClosestReferenceIndex] = min(validDistanceToReference);

indexClosestMean = validRowIndices(localClosestMeanIndex);
indexClosestReference = validRowIndices(localClosestReferenceIndex);

patientClosestMean = resultsThickness.Patient(indexClosestMean);
patientClosestReference = resultsThickness.Patient(indexClosestReference);

sortedByMean = sortrows(resultsThickness, 'Distance_To_Group_Mean_mm', 'ascend');
sortedByReference = sortrows(resultsThickness, 'Distance_To_Reference_CWT_mm', 'ascend');

statisticsTable = table( ...
    string(groupName), string(groupCode), ...
    referenceCWT_mm, referenceSD_mm, ...
    groupMeanMM, groupStdMM, groupMedianMM, ...
    minGroupMM, maxGroupMM, ...
    resultsThickness.Patient(indexMin), resultsThickness.Patient(indexMax), ...
    patientClosestMean, resultsThickness.Mean_Directional_Thickness_mm(indexClosestMean), minimumDistanceToMean, ...
    patientClosestReference, resultsThickness.Mean_Directional_Thickness_mm(indexClosestReference), minimumDistanceToReference, ...
    'VariableNames', {'Group','Group_Code', ...
    'Reference_CWT_mm','Reference_SD_mm', ...
    'Group_Mean_mm','Group_Std_mm','Group_Median_mm', ...
    'Group_Min_mm','Group_Max_mm', ...
    'Patient_Min','Patient_Max', ...
    'Patient_Closest_To_Group_Mean','Thickness_Closest_To_Group_Mean_mm','Difference_From_Group_Mean_mm', ...
    'Patient_Closest_To_Reference_CWT','Thickness_Closest_To_Reference_CWT_mm','Difference_From_Reference_CWT_mm'});

disp('================ DIRECTIONAL THICKNESS RESULTS ================');
disp(resultsThickness);

disp('================ GROUP STATISTICS ================');
disp(statisticsTable);

disp('================ PATIENTS CLOSEST TO GROUP MEAN ================');
disp(sortedByMean);

disp('================ PATIENTS CLOSEST TO REFERENCE CWT ================');
disp(sortedByReference);

%% ===================== SAVE EXCEL FILE =====================

outputExcel = fullfile(tablesFolder, lower(groupCode) + "_directional_cwt_results.xlsx");

writetable(resultsThickness, outputExcel, 'Sheet', 'Patient_Summary');
writetable(statisticsTable, outputExcel, 'Sheet', 'Statistics');
writetable(sortedByMean, outputExcel, 'Sheet', 'Closest_Group_Mean');
writetable(sortedByReference, outputExcel, 'Sheet', 'Closest_Reference_CWT');
writetable(detailsAP, outputExcel, 'Sheet', 'Details_Anterior_Posterior');
writetable(detailsLR, outputExcel, 'Sheet', 'Details_Left_Right');

fprintf('\nExcel results saved in:\n%s\n', outputExcel);

%% ===================== FIGURES =====================

x = 1:numberOfPatients;

fig1 = figure('Color','w', 'Name','Mean directional thickness');
bar(resultsThickness.Mean_Directional_Thickness_mm);
hold on;
yline(groupMeanMM, '--', 'Group mean', 'LineWidth', 2);
yline(referenceCWT_mm, '-.', 'Reference CWT', 'LineWidth', 2);
yline(referenceCWT_mm + referenceSD_mm, ':', '+ SD', 'LineWidth', 1.5);
yline(referenceCWT_mm - referenceSD_mm, ':', '- SD', 'LineWidth', 1.5);
plot(indexClosestReference, resultsThickness.Mean_Directional_Thickness_mm(indexClosestReference), ...
    'o', 'MarkerSize', 12, 'LineWidth', 3);
hold off;
grid on;
box on;
xticks(x);
xticklabels(resultsThickness.Patient);
xlabel('Patients');
ylabel('Mean directional thoracic thickness (mm)');
title(['Mean Directional Thoracic Thickness - ', groupName]);

saveas(fig1, fullfile(figuresFolder, lower(groupCode) + "_directional_cwt_vs_reference.png"));
savefig(fig1, fullfile(figuresFolder, lower(groupCode) + "_directional_cwt_vs_reference.fig"));

fig2 = figure('Color','w', 'Name','Directional thickness components');
bar([resultsThickness.Anterior_Mean_mm ...
     resultsThickness.Posterior_Mean_mm ...
     resultsThickness.Left_Mean_mm ...
     resultsThickness.Right_Mean_mm]);
grid on;
box on;
xticks(x);
xticklabels(resultsThickness.Patient);
xlabel('Patients');
ylabel('Mean thickness (mm)');
title(['Directional Thickness Components - ', groupName]);
legend({'Anterior','Posterior','Left','Right'}, 'Location', 'best');

saveas(fig2, fullfile(figuresFolder, lower(groupCode) + "_directional_components.png"));
savefig(fig2, fullfile(figuresFolder, lower(groupCode) + "_directional_components.fig"));

fig3 = figure('Color','w', 'Name','Distance to reference CWT');
bar(resultsThickness.Distance_To_Reference_CWT_mm);
grid on;
box on;
xticks(x);
xticklabels(resultsThickness.Patient);
xlabel('Patients');
ylabel('Distance to reference CWT (mm)');
title(['Distance to Reference CWT - ', groupName]);

saveas(fig3, fullfile(figuresFolder, lower(groupCode) + "_distance_to_reference_cwt.png"));
savefig(fig3, fullfile(figuresFolder, lower(groupCode) + "_distance_to_reference_cwt.fig"));

fig4 = figure('Color','w', 'Name','Distance to group mean');
bar(resultsThickness.Distance_To_Group_Mean_mm);
grid on;
box on;
xticks(x);
xticklabels(resultsThickness.Patient);
xlabel('Patients');
ylabel('Distance to group mean (mm)');
title(['Distance to Group Mean - ', groupName]);

saveas(fig4, fullfile(figuresFolder, lower(groupCode) + "_distance_to_group_mean.png"));
savefig(fig4, fullfile(figuresFolder, lower(groupCode) + "_distance_to_group_mean.fig"));

%% ===================== DETAIL FIGURES FOR CLOSEST REFERENCE PATIENT =====================

patientReference = patientClosestReference;

indexAP = detailsAP.Patient == patientReference;

if any(indexAP)
    fig5 = figure('Color','w', 'Name','Anterior and posterior detail');
    plot(detailsAP.Slice_Index(indexAP), detailsAP.Anterior_mm(indexAP), '-o', 'LineWidth', 2);
    hold on;
    plot(detailsAP.Slice_Index(indexAP), detailsAP.Posterior_mm(indexAP), '-o', 'LineWidth', 2);
    hold off;
    grid on;
    box on;
    xlabel('Slice index');
    ylabel('Thickness (mm)');
    title(['Anterior / Posterior Thickness - Patient ', char(patientReference)]);
    legend({'Anterior','Posterior'}, 'Location', 'best');

    saveas(fig5, fullfile(figuresFolder, lower(groupCode) + "_ap_detail_closest_reference.png"));
    savefig(fig5, fullfile(figuresFolder, lower(groupCode) + "_ap_detail_closest_reference.fig"));
end

indexLR = detailsLR.Patient == patientReference;

if any(indexLR)
    fig6 = figure('Color','w', 'Name','Left and right detail');
    plot(detailsLR.Slice_Index(indexLR), detailsLR.Left_mm(indexLR), '-o', 'LineWidth', 2);
    hold on;
    plot(detailsLR.Slice_Index(indexLR), detailsLR.Right_mm(indexLR), '-o', 'LineWidth', 2);
    hold off;
    grid on;
    box on;
    xlabel('Slice index');
    ylabel('Thickness (mm)');
    title(['Left / Right Thickness - Patient ', char(patientReference)]);
    legend({'Left','Right'}, 'Location', 'best');

    saveas(fig6, fullfile(figuresFolder, lower(groupCode) + "_lr_detail_closest_reference.png"));
    savefig(fig6, fullfile(figuresFolder, lower(groupCode) + "_lr_detail_closest_reference.fig"));
end

fprintf('\n===== Processing completed successfully =====\n');
fprintf('Tables saved in:\n%s\n', tablesFolder);
fprintf('Figures saved in:\n%s\n', figuresFolder);
fprintf('Patient closest to reference CWT: %s\n', patientClosestReference);
fprintf('Mean directional thickness: %.2f mm\n', ...
    resultsThickness.Mean_Directional_Thickness_mm(indexClosestReference));

%% ============================================================
% LOCAL FUNCTIONS
%% ============================================================

function columnName = getExistingColumn(inputTable, possibleNames)

    columnName = "";

    for i = 1:numel(possibleNames)
        if ismember(possibleNames{i}, inputTable.Properties.VariableNames)
            columnName = possibleNames{i};
            return;
        end
    end

    error('None of the required columns was found: %s', strjoin(possibleNames, ', '));
end

function [anteriorMM, posteriorMM] = calculateAnteriorPosteriorThickness( ...
    lung2D, body2D, spacingY, minDistanceMM, maxDistanceMM, percentileValue)

    fullBody = body2D | lung2D;

    anteriorList = [];
    posteriorList = [];

    for c = 1:size(lung2D, 2)

        lungRows = find(lung2D(:, c));
        bodyRows = find(fullBody(:, c));

        if isempty(lungRows) || isempty(bodyRows)
            continue;
        end

        anteriorSkinY = min(bodyRows);
        anteriorLungY = min(lungRows);

        posteriorLungY = max(lungRows);
        posteriorSkinY = max(bodyRows);

        anteriorDistance = (anteriorLungY - anteriorSkinY) * spacingY;
        posteriorDistance = (posteriorSkinY - posteriorLungY) * spacingY;

        if anteriorDistance > minDistanceMM && anteriorDistance < maxDistanceMM
            anteriorList(end+1,1) = anteriorDistance; %#ok<AGROW>
        end

        if posteriorDistance > minDistanceMM && posteriorDistance < maxDistanceMM
            posteriorList(end+1,1) = posteriorDistance; %#ok<AGROW>
        end
    end

    if isempty(anteriorList)
        anteriorMM = NaN;
    else
        anteriorMM = prctile(anteriorList, percentileValue);
    end

    if isempty(posteriorList)
        posteriorMM = NaN;
    else
        posteriorMM = prctile(posteriorList, percentileValue);
    end
end

function [leftMM, rightMM] = calculateLeftRightThickness( ...
    lung2D, body2D, spacingX, minDistanceMM, maxDistanceMM, percentileValue)

    fullBody = body2D | lung2D;

    leftList = [];
    rightList = [];

    for r = 1:size(lung2D, 1)

        lungCols = find(lung2D(r, :));
        bodyCols = find(fullBody(r, :));

        if isempty(lungCols) || isempty(bodyCols)
            continue;
        end

        leftSkinX = min(bodyCols);
        leftLungX = min(lungCols);

        rightLungX = max(lungCols);
        rightSkinX = max(bodyCols);

        leftDistance = (leftLungX - leftSkinX) * spacingX;
        rightDistance = (rightSkinX - rightLungX) * spacingX;

        if leftDistance > minDistanceMM && leftDistance < maxDistanceMM
            leftList(end+1,1) = leftDistance; %#ok<AGROW>
        end

        if rightDistance > minDistanceMM && rightDistance < maxDistanceMM
            rightList(end+1,1) = rightDistance; %#ok<AGROW>
        end
    end

    if isempty(leftList)
        leftMM = NaN;
    else
        leftMM = prctile(leftList, percentileValue);
    end

    if isempty(rightList)
        rightMM = NaN;
    else
        rightMM = prctile(rightList, percentileValue);
    end
end

function outputVector = padToLength(inputVector, targetLength)

    outputVector = NaN(targetLength, 1);
    numberOfValues = min(numel(inputVector), targetLength);

    if numberOfValues > 0
        outputVector(1:numberOfValues) = inputVector(1:numberOfValues);
    end
end
```
