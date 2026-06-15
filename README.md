# moroccan-digital-voxelized-thoracic-phantoms---UH1-ISSS
Development of voxelized digital thoracic phantoms representative of the Moroccan population using CT images., 3D Slicer, MONAI auto3dseg, Lung GMM , TotalSegmentator and MATLAB.
# Moroccan Digital Voxelized Thoracic Phantoms

## Description

This project focuses on the development of voxelized digital thoracic phantoms representative of the Moroccan population using CT images.

The study includes three groups:

* Moroccan adult male
* Moroccan adult female
* Moroccan child

The workflow is based on CT image processing, automatic segmentation, manual correction, morphometric analysis, comparison of segmentation methods, and multicriteria selection of representative thoracic phantoms.

## Tools and Software

* 3D Slicer
* TotalSegmentator
* MONAI Auto3DSeg
* Lung CT GMM
* MATLAB
* Microsoft Excel

## Methodology

The main steps of the project are:

1. Importing thoracic CT images
2. Performing automatic segmentation using AI-based tools
3. Applying manual correction to the segmented structures
4. Exporting voxelized labelmaps
5. Calculating morphometric parameters:

   * Lung volume
   * Chest Wall Thickness
   * Anteroposterior diameter
6. Comparing segmentation methods
7. Selecting representative phantoms using a multicriteria score

## Segmented Structures

For male and child phantoms:

| Label | Structure |
| ----- | --------- |
| 1     | Lungs     |
| 2     | Body      |
| 3     | Bones     |

For female phantom:

| Label | Structure |
| ----- | --------- |
| 1     | Lungs     |
| 2     | Body      |
| 3     | Breasts   |
| 4     | Bones     |

## Representative Phantoms

The final selected representative phantoms are:

| Group  | Selected Patient |
| ------ | ---------------- |
| Male   | H5               |
| Female | F8               |
| Child  | E3               |

## Privacy Statement

Original CT images and patient data are not included in this repository due to medical confidentiality and patient privacy.

Only anonymized results, scripts, figures, and methodological documents are shared.

## Author

Oussama Aabi
ISSS Settat – Université Hassan 1er
