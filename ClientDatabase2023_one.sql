-- Create the database. 

CREATE DATABASE ClientDatabase2023

USE ClientDatabase2023

GO
-- Create Members Table. 
CREATE TABLE [Members] (
   [MemberID] int Identity(1,1) NOT NULL PRIMARY KEY,
   [FirstName] nvarchar(50) NOT NULL,
   [LastName] nvarchar(50) NOT NULL,
   [Address] nvarchar(225) NOT NULL,
   [DateOfBirth] date NOT NULL,
   [DateJoined] date NOT NULL,
   [DateLeft] date NULL,
   [Username] nvarchar(50) NOT NULL,
   [PasswordHash] Binary(64) NOT NULL,
   Salt Uniqueidentifier,
   [EmailAddress] nvarchar(100) UNIQUE NULL CHECK ([EmailAddress] LIKE '%_@_%._%'),
   [PhoneNumber] nvarchar(20) NULL);

 --Create unique filtered index on Email column for non-null values
CREATE UNIQUE INDEX UQ_Member_Emai1
ON Members ([EmailAddress])
WHERE [EmailAddress] IS NOT NULL;

-- Catalogue Items Table
CREATE TABLE CatalogueItems (
   [ItemID] int Identity(1,1) NOT NULL PRIMARY KEY,
   [ItemTitle] nvarchar(100) NOT NULL,
   [ItemType] nvarchar(50) NOT NULL,
   [Author] nvarchar(100) NOT NULL,
   [YearOfPublication] date NOT NULL,
   [DateAddedToCollection] date NOT NULL,
   [CurrentStatus] nvarchar(20) NOT NULL,
   [LostOrRemovedDate] date NULL,
   [ISBN] nvarchar(20) NULL,
   CONSTRAINT CHK_ItemType CHECK (ItemType IN ('Book', 'Journal', 'DVD', 'Other Media')),
   CONSTRAINT CHK_CurrentStatus CHECK (CurrentStatus IN ('On Loan', 'Overdue', 'Available', 'Lost/Removed')),
   CONSTRAINT CHK_ISBN CHECK ((ItemType = 'Book' AND ISBN IS NOT NULL) OR (ItemType != 'Book'))
);
 
-- Loans Table
CREATE TABLE Loans (
   [LoanID] int Identity(1,1) NOT NULL PRIMARY KEY,
   [MemberID] int NOT NULL,
   [ItemID] int NOT NULL,
   [LoanDate] date NOT NULL,
   [DueDate]date NOT NULL,
   [ReturnDate] date NULL,
   CONSTRAINT CHK_LoanStatus CHECK (ReturnDate IS NULL OR ReturnDate <= DueDate),
   CONSTRAINT CHK_DueDate CHECK (DueDate >= LoanDate),
   CONSTRAINT FK_Loans_Members FOREIGN KEY (MemberID) REFERENCES Members(MemberID),
   CONSTRAINT FK_Loans_CatalogueItems FOREIGN KEY (ItemID) REFERENCES CatalogueItems(ItemID)
);

-- Fine Table
CREATE TABLE Fine (
   [FineID]  int Identity(1,1) NOT NULL PRIMARY KEY,
   [LoanID] int NOT NULL,
   [FineAmount] decimal(10,2) NOT NULL,
    CONSTRAINT FK_Fine_Loans FOREIGN KEY (LoanID) REFERENCES Loans(LoanID)
);

-- Repayment Table
CREATE TABLE Repayment (
   [RepaymentID]  int Identity(1,1) NOT NULL PRIMARY KEY,
   [LoanID] int NOT NULL,
   [RepaymentDateTime] datetime NOT NULL,
   [RepaymentAmount] decimal(10,2) NOT NULL,
   [RepaymentMethod] nvarchar(10) NOT NULL,
    CONSTRAINT CHK_RepaymentMethod CHECK (RepaymentMethod IN ('cash', 'card')),
    CONSTRAINT FK_Repayment_Loans FOREIGN KEY (LoanID) REFERENCES Loans(LoanID)
);

-- Stored procedure to search the catalogue for matching character strings by title
GO
CREATE PROCEDURE SearchCatalogue
    @searchString NVARCHAR(100)
AS
BEGIN
    SELECT *
    FROM CatalogueItems
    WHERE ItemTitle LIKE '%' + @searchString + '%'
    ORDER BY YearOfPublication DESC
END

-- Execute stored procedure and display the results for search catalogue say title is my name (dayo samuel)
EXEC SearchCatalogue @searchString = 'dayo samuel';


-- Stored procedure to return a full list of all items currently on loan which have a due date of less than five days from the current date

GO
CREATE PROCEDURE GetItemsDueSoon
AS
BEGIN
    SELECT *
    FROM Loans l
    INNER JOIN CatalogueItems ci ON l.ItemID = ci.ItemID
    WHERE l.ReturnDate IS NULL
    AND l.DueDate <= DATEADD(day, 5, GETDATE())
END
GO

-- Execute stored procedure and display the results 
EXEC GetItemsDueSoon;

-- Insert an new Member into the database

GO
CREATE PROCEDURE InsertMember
@FirstName NVARCHAR(50),
@LastName NVARCHAR(50),
@Address NVARCHAR(225),
@DateOfBirth DATE,
@DateJoined DATE,
@Username NVARCHAR(50),
@Password NVARCHAR(100),
@EmailAddress NVARCHAR(100),
@PhoneNumber NVARCHAR(20)
AS
DECLARE @Salt UNIQUEIDENTIFIER=NEWID()
DECLARE @PasswordHash BINARY(64) = HASHBYTES('SHA2_512', @Password + CAST(@Salt AS NVARCHAR(36)))
INSERT INTO Members (FirstName, LastName, [Address], DateOfBirth, DateJoined, Username, PasswordHash, Salt, EmailAddress, PhoneNumber)
VALUES (@FirstName, @LastName, @Address, @DateOfBirth, @DateJoined, @Username, @PasswordHash, @Salt, @EmailAddress, @PhoneNumber)
GO

-- -- Execute stored procedure for new member insert

EXEC InsertMember
@FirstName = 'dayo',
@LastName = 'samuel',
@Address = '117 seaford St.',
@DateOfBirth = '1995-01-01',
@DateJoined = '2022-04-05',
@Username = 'rgghgf',
@Password = 'fgfghghb',
@EmailAddress = 'dayosamuel@gmail.com',
@PhoneNumber = '123-4545-7890'

-- View what's in the table

SELECT * FROM Members

--Update the details for an existing member

GO

CREATE PROCEDURE UpdateMemberDetails
@MemberID INT,
@FirstName NVARCHAR(50),
@LastName NVARCHAR(50),
@Address NVARCHAR(225),
@DateOfBirth DATE,
@EmailAddress NVARCHAR(100),
@PhoneNumber NVARCHAR(20)
AS
BEGIN
UPDATE Members
SET
FirstName = @FirstName,
LastName = @LastName,
[Address] = @Address,
DateOfBirth = @DateOfBirth,
EmailAddress = @EmailAddress,
PhoneNumber = @PhoneNumber
WHERE
MemberID = @MemberID
END
GO

-- -- Execute stored procedure for Update member insert

EXEC UpdateMemberDetails
@MemberID = 1,
@FirstName = 'Dayo',
@LastName = 'Love',
@Address = '406 kent St.',
@DateOfBirth = '1995-01-01',
@EmailAddress = 'dayosamuel@gmail.com',
@PhoneNumber = '939-323-1222'

-- View what's updated in the table

SELECT * FROM Members

-- View Loan History
GO
CREATE VIEW LoanHistory AS
    SELECT m.FirstName, m.LastName, ci.ItemTitle, ci.ItemType, ci.Author, ci.YearOfPublication, l.LoanDate, l.DueDate, l.ReturnDate, f.FineAmount
    FROM Loans l
    INNER JOIN Members m ON l.MemberID = m.MemberID
    INNER JOIN CatalogueItems ci ON l.ItemID = ci.ItemID
    LEFT JOIN Fine f ON l.LoanID = f.LoanID
GO

-- View Loan history

SELECT * FROM LoanHistory

--Create a trigger so that the current status of an item automatically updates to  Available when the book is returned

GO

CREATE TRIGGER trg_UpdateItemStatus
ON Loans
AFTER UPDATE
AS
BEGIN
    IF UPDATE(ReturnDate)
    BEGIN
        UPDATE CatalogueItems
        SET CurrentStatus = 'Available'
        FROM CatalogueItems ci
        INNER JOIN inserted i ON i.ItemID = ci.ItemID
        WHERE i.ReturnDate IS NOT NULL
    END
END

GO

-- SELECT query which allows the library to identify the total number of loans made on a specified date.

SELECT COUNT(*) AS TotalLoans
FROM Loans
WHERE LoanDate = '2023-04-05'


GO 


-- ALTER Author and YearOfPublication column

ALTER TABLE CatalogueItems ALTER COLUMN Author nvarchar(100) NULL
ALTER TABLE CatalogueItems ALTER COLUMN YearOfPublication date NULL



-- Inserting records into members table 
INSERT INTO Members (FirstName, LastName, Address, DateOfBirth, DateJoined, DateLeft, Username, PasswordHash, Salt, EmailAddress, PhoneNumber)
VALUES
('Chinwe', 'Okafor', '123 Main St', '1980-01-01', '2022-01-01', NULL, 'chinweokafor', 0x1234567890ABCDEF, NEWID(), 'chinweokafor@gmail.com', '+2348021234567'),
('Chuka', 'Okeke', '456 Oak Ave', '1985-02-15', '2022-01-01', NULL, 'chukaokeke', 0x1234567890ABCDEF, NEWID(), 'chukaokeke@gmail.com', '+2348022345678'),
('Femi', 'Adeleke', '789 Elm St', '1990-03-30', '2022-02-01', NULL, 'femiadeleke', 0x1234567890ABCDEF, NEWID(), 'femiadeleke@gmail.com', '+2348023456789'),
('Chiamaka', 'Obi', '456 Pine Rd', '1995-04-14', '2022-02-15', NULL, 'chiamakaobi', 0x1234567890ABCDEF, NEWID(), 'chiamakaobi@gmail.com', '+2348024567890'),
('Oluwaseun', 'Adeyemi', '321 Birch Dr', '2000-05-01', '2022-03-01', NULL, 'oluwaseunadeyemi', 0x1234567890ABCDEF, NEWID(), 'oluwaseunadeyemi@gmail.com', '+2348025678901'),
('Adanna', 'Okonkwo', '987 Maple St', '2005-06-15', '2022-04-01', NULL, 'adannaokonkwo', 0x1234567890ABCDEF, NEWID(), 'adannaokonkwo@gmail.com', '+2348026789012'),
('Nnamdi', 'Okafor', '456 Cedar Ave', '2010-07-30', '2022-05-01', NULL, 'nnamdiokafor', 0x1234567890ABCDEF, NEWID(), 'nnamdiokafor@gmail.com', '+2348027890123'),
('Chinyere', 'Nwachukwu', '123 Walnut Blvd', '2015-08-14', '2022-06-01', NULL, 'chinyerenwachukwu', 0x1234567890ABCDEF, NEWID(), NULL, '+2348028901234'),
('Ademola', 'Ogunsanwo', '789 Pine St', '2020-09-01', '2022-07-01', NULL, 'ademolaogunsanwo', 0x1234567890ABCDEF, NEWID(), 'ademolaogunsanwo@gmail.com', '+2348029012345'),
('Olamide', 'Adekunle', '456 Maple Rd', '2021-10-15', '2022-08-01', NULL, 'olamideadekunle', 0x1234567890ABCDEF, NEWID(), 'olamideadekunle@gmail.com', '+2348020123456')


SELECT * FROM Members



-- Inserting records into CatalogueItems table 
INSERT INTO CatalogueItems (ItemTitle, ItemType, Author, YearOfPublication, DateAddedToCollection, CurrentStatus, LostOrRemovedDate, ISBN)
VALUES
('Things Fall Apart', 'Book', 'Chinua Achebe', '1958', '2022-01-01', 'Available', NULL, '978-0-385-47454-2'),
('Half of a Yellow Sun', 'Book', 'Chimamanda Ngozi Adichie', '2006', '2022-01-01', 'Available', NULL, '978-0-307-27891-1'),
('The Secret Lives of Baba Segi’s Wives', 'Book', 'Lola Shoneyin', '2010', '2022-02-01', 'Available', NULL, '978-0-06-194638-8'),
('The Joys of Motherhood', 'Book', 'Buchi Emecheta', '1979', '2022-02-01', 'On Loan', NULL, '978-0-8070-0025-5'),
('Aké: The Years of Childhood', 'Book', 'Wole Soyinka', '1981', '2022-03-01', 'On Loan', NULL, '978-0-394-51504-1'),
('The Famished Road', 'Book', 'Ben Okri', '1991', '2022-03-01', 'Overdue', '2023-03-15', '978-0-553-56320-4'),
('Americanah', 'Book', 'Chimamanda Ngozi Adichie', '2013', '2022-04-01', 'Lost/Removed', '2023-02-28', '908-0-553-56320-4'),
('BusinessDay', 'Journal', NULL, NULL, '2022-05-01', 'Available', NULL, NULL),
('The Guardian', 'Journal', NULL, NULL, '2022-05-01', 'Available', NULL, NULL),
('Lionheart', 'DVD', NULL, '2018', '2022-06-01', 'On Loan', NULL, NULL),
('October 1', 'DVD', NULL, '2014', '2022-07-01', 'Available', NULL, NULL),
('King of Boys', 'DVD', NULL, '2018', '2022-08-01', 'Available', NULL, NULL),
('Lagos: Before the 21st Century', 'Other Media', 'Kunle Tejuosho', '2011', '2022-09-01', 'Available', NULL, NULL),
('Nollywood: The Nigerian Film Industry', 'Other Media', 'Franco Sacchi', '2007', '2022-10-01', 'On Loan', NULL, NULL);

SELECT * FROM CatalogueItems


-- Inserting records into Loans table 

INSERT INTO Loans (MemberID, ItemID, LoanDate, DueDate, ReturnDate)
VALUES
(1, 4, '2023-04-05', '2023-04-12', NULL),
(2, 5, '2023-04-03', '2023-04-10', '2023-04-08'),
(3, 6, '2023-04-02', '2023-04-09', '2023-04-09'),
(4, 7, '2023-04-01', '2023-04-08', NULL),
(5, 10, '2023-03-30', '2023-04-06', NULL),
(6, 12, '2023-03-27', '2023-04-03', '2023-04-02'),
(7, 14, '2023-03-25', '2023-04-01', NULL);

SELECT * FROM Loans


-- Execute stored procedure and display the results for search catalogue say title is my name (The Joys of Motherhood)
EXEC SearchCatalogue @searchString = 'The Joys of Motherhood';

-- Execute stored procedure and display the results 
EXEC GetItemsDueSoon;


-- Procedure to Calculate Overdue Fees at 10p per day

GO
CREATE PROCEDURE CalculateOverdueFees
AS
BEGIN
    -- Insert or update overdue fees for overdue loans
    MERGE INTO Fine AS F
    USING
    (
        SELECT
            L.LoanID,
            DATEDIFF(day, L.DueDate, GETDATE()) * 0.1 AS OverdueFee
        FROM
            Loans L
        WHERE
            L.ReturnDate IS NULL
            AND L.DueDate < GETDATE()
    ) AS Overdue
    ON (F.LoanID = Overdue.LoanID)
    WHEN MATCHED THEN
        UPDATE
        SET F.FineAmount = Overdue.OverdueFee
    WHEN NOT MATCHED THEN
        INSERT (LoanID, FineAmount)
        VALUES (Overdue.LoanID, Overdue.OverdueFee);
END;
GO


EXEC CalculateOverdueFees;

SELECT * FROM LoanHistory

SELECT * FROM Fine



-- Trigger to Calculate Overdue Fees at 10p per day

GO

CREATE TRIGGER CalculateOverdueFeesOnUpdate
ON Loans
AFTER UPDATE
AS
BEGIN
    -- Insert or update overdue fees for overdue loans
    MERGE INTO Fine AS F
    USING
    (
        SELECT
            L.LoanID,
            DATEDIFF(day, L.DueDate, GETDATE()) * 0.1 AS OverdueFee
        FROM
            Loans L
            INNER JOIN inserted I ON L.LoanID = I.LoanID
        WHERE
            L.ReturnDate IS NULL
            AND L.DueDate < GETDATE()
    ) AS Overdue
    ON (F.LoanID = Overdue.LoanID)
    WHEN MATCHED THEN
        UPDATE
        SET F.FineAmount = Overdue.OverdueFee
    WHEN NOT MATCHED THEN
        INSERT (LoanID, FineAmount)
        VALUES (Overdue.LoanID, Overdue.OverdueFee);
END;
GO


SELECT * FROM LoanHistory

SELECT * FROM Fine

-- Shows the current status of all items in the library's collection

GO
CREATE VIEW CurrentInventoryStatus AS
    SELECT ci.ItemID, ci.ItemTitle, ci.ItemType, ci.Author, ci.YearOfPublication, ci.ISBN, ci.CurrentStatus,
           COUNT(l.LoanID) AS NumberOfLoans
    FROM CatalogueItems ci
    LEFT JOIN Loans l ON ci.ItemID = l.ItemID
    GROUP BY ci.ItemID, ci.ItemTitle, ci.ItemType, ci.Author, ci.YearOfPublication, ci.ISBN, ci.CurrentStatus
GO

SELECT * FROM CurrentInventoryStatus;


-- User function for calculating the fine amount for an overdue loan.
GO
CREATE FUNCTION CalculateFineAmount
(@DueDate DATE, @ReturnDate DATE)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @FineAmount DECIMAL(10,2)
    IF @ReturnDate > @DueDate
    BEGIN
        SET @FineAmount = DATEDIFF(day, @DueDate, @ReturnDate) * 0.1
    END
    ELSE
    BEGIN
        SET @FineAmount = 0
    END
    RETURN @FineAmount
END
GO

SELECT dbo.CalculateFineAmount('2023-04-01', '2023-04-07') AS FineAmount;
