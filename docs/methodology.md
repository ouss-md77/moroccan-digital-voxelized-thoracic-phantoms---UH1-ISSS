# Methodology

This project aims to develop voxelized digital thoracic phantoms representative of the Moroccan population using CT images.

The workflow includes the following steps:

1. Importation of thoracic CT images
2. Automatic segmentation using AI-based tools
3. Manual correction of segmented structures
4. Export of voxelized labelmaps
5. Calculation of morphometric parameters
6. Comparison of segmentation methods
7. Selection of representative phantoms using a multicriteria score

## CT Image Processing

Thoracic CT images were processed using 3D Slicer. The images were converted into voxelized labelmaps, where each voxel was assigned to an anatomical structure.

## Segmentation

Automatic segmentation was performed using TotalSegmentator. Other segmentation approaches, such as MONAI Auto3DSeg and Lung CT GMM, were also considered for comparison.

Manual correction was performed when necessary to improve segmentation quality.

## Morphometric Analysis

The following parameters were calculated:

- Lung volume
- Chest Wall Thickness
- Anteroposterior diameter

These parameters were used to compare patients within each group and to select the most representative phantom.

## Multicriteria Selection

A multicriteria score was used to select the representative patient for each group.

The final selected phantoms were:

| Group | Selected patient |
|---|---|
| Male | H5 |
| Female | F8 |
| Child | E3 |
