-- 1. Change the format of the SaleDate column from yyyy-mm-dd 00:00:00:000 TO  yyyy-mm-dd with the Date data type

ALTER TABLE NashvilleHousing
ALTER COLUMN SaleDate Date;

-----------------------------------------------------------------------
-- 2. Populate the Property Address column
		--Upon exploring the data, I've found that there are some NULL values in the PropertyAddress column
			--Interestingly, they are NULL but share the same ParcelID of another row which has a property address
			-- FOR example,                
			--	Unique ID			ParcelID           PropertyAddress
			--		1				234					123 Example Street
			--		2				234					NULL
		
			-- For this reason, I'm going to update the NUll-values in the  PropertyAddress columns to those of the same ParcellID

-- Join the table with itself to identify rows with the same ParcelID, but different PropertyAddress values(NULL vs values)
SELECT a.ParcelID, a.PropertyAddress, b.ParcelID, b.PropertyAddress FROM
PortfolioProjects..NashvilleHousing a
JOIN 
PortfolioProjects..NashvilleHousing b 
ON a.ParcelID = b.ParcelID AND a.UniqueID <> b.UniqueID
WHERE a.PropertyAddress IS NULL

-- Update the table using ISNULL(a,b). If ISNULL of a is True then set the PropertyAddress value to b
Update a
SET a.PropertyAddress = ISNULL(a.PropertyAddress,b.PropertyAddress)
FROM
PortfolioProjects..NashvilleHousing a
JOIN 
PortfolioProjects..NashvilleHousing b 
ON a.ParcelID = b.ParcelID AND a.UniqueID <> b.UniqueID
WHERE a.PropertyAddress IS NULL

---------------------------------------------------------------------------------

-- 3. Breaking Address into individual columns (Address, City, State) for the PropertyAddress and OwnerAddress column
	--		Address					->		   Street			  City			State
	-- 123Address,Nashville,TN		->		123Address			Nashville		TN

ALTER TABLE PortfolioProjects..NashvilleHousing
ADD PropertyStreet nvarchar(255), PropertyCity Nvarchar(255)

-- Using substring(string, start, end) to extract the street/city from PropertyAddress
-- CHARINDEX(character, string) return the index of character
UPDATE PortfolioProjects..NashvilleHousing
SET PropertyStreet = SUBSTRING(PropertyAddress,1,CHARINDEX(',',PropertyAddress)-1),
	PropertyCity  = SUBSTRING(PropertyAddress, CHARINDEX(',',PropertyAddress)+1, len(PropertyAddress))


ALTER TABLE PortfolioProjects..NashvilleHousing
ADD OwnerStreet nvarchar(255), OwnerCity nvarchar(255), OwnerState nvarchar(255)

-- USING PARSENAME to extract substrings from a string seperated by a '.'
-- That's why REPLACE is used to replace ',' with '.'
UPDATE PortfolioProjects..NashvilleHousing
SET OwnerStreet = PARSENAME(REPLACE(OwnerAddress,',','.'),3),
OwnerCity = PARSENAME(REPLACE(OwnerAddress,',','.'),2),
OwnerState = PARSENAME(REPLACE(OwnerAddress,',','.'),1)


-----------------------------------------------------------------------------------
-- 4. SoldasVacant column has 4 values. N,Yes,Y,No. Change them to only Yes and No

UPDATE PortfolioProjects..NashvilleHousing 
SET SoldasVacant = CASE WHEN SoldasVacant = 'Y' THEN 'YES'
						WHEN SoldasVacant = 'N' THEN 'No' 
						ELSE SoldasVacant
						END
						FROM PortfolioProjects..NashvilleHousing 

-----------------------------------------------------------------------------------------------

--5. Remove duplicates.
	-- Upon examining the dataset, many rows have different UniqueID, but the rest of the columns have the same value
	-- So, I'm going to remove the duplicates and only keep the one with the smalles Unique ID
-- LOGIC
	-- 1. Create a new column row_num that contains a sequential number to each row with a specified partition (1)
	-- Delete all rows with row_num <> 1 (not unique)
SELECT ParcelID,ROW_NUMBER() OVER (Partition by ParcelID,
										LandUse, PropertyAddress,
										SaleDate, SalePrice, LegalReference,
										SoldAsVacant, OwnerAddress, Acreage, TaxDistrict, LandValue,
										BuildingValue, TotalValue, YearBuilt, Bedrooms, Fullbath, HalfBath
										ORDER BY UniqueID
									) row_num
FROM PortfolioProjects..NashvilleHousing 

-- Create row_num column
ALTER TABLE PortfolioProjects..NashvilleHousing
ADD row_num int

-- Add values to the row_num columns with the value from ROW_NUMBER()
UPDATE PortfolioProjects..NashvilleHousing
SET row_num = subquery.row_num
FROM (
    SELECT UniqueID, ROW_NUMBER() OVER (PARTITION BY ParcelID,
										LandUse, PropertyAddress,
										SaleDate, SalePrice, LegalReference,
										SoldAsVacant, OwnerAddress, Acreage, TaxDistrict, LandValue,
										BuildingValue, TotalValue, YearBuilt, Bedrooms, Fullbath, HalfBath
										ORDER BY UniqueID) AS row_num
    FROM PortfolioProjects..NashvilleHousing
) AS subquery
WHERE PortfolioProjects..NashvilleHousing.UniqueID = subquery.UniqueID;

-- Delete all rows where row_num is not 1(duplicated)
DELETE FROM PortfolioProjects..NashvilleHousing   
WHERE row_num <>1;

--6. Delete Unused columns
	-- Drop PropertyAddress and OwnerAddress because they have been splitted them into different columns (Street,Address,State)

ALTER TABLE PortfolioProjects..NashvilleHousing   
DROP COLUMN PropertyAddress, OwnerAddress