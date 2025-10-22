-- CMDB Database Schema for AI Assistant
-- Run these scripts in your RDS SQL Server instance

-- Create main tables if they don't exist
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='Devices' AND xtype='U')
BEGIN
    CREATE TABLE [dbo].[Devices] (
        [Id] INT IDENTITY(1,1) PRIMARY KEY,
        [Name] NVARCHAR(255) NOT NULL,
        [SerialNumber] NVARCHAR(100) UNIQUE,
        [Type] NVARCHAR(100) NOT NULL,
        [Status] NVARCHAR(50) DEFAULT 'Active',
        [Environment] NVARCHAR(50),
        [Owner] NVARCHAR(255),
        [Location] NVARCHAR(255),
        [MaStartDate] DATE,
        [MaEndDate] DATE,
        [MaCost] DECIMAL(10,2),
        [PurchaseDate] DATE,
        [PurchaseCost] DECIMAL(10,2),
        [Vendor] NVARCHAR(255),
        [Model] NVARCHAR(255),
        [Description] NTEXT,
        [CreatedAt] DATETIME2 DEFAULT GETDATE(),
        [UpdatedAt] DATETIME2 DEFAULT GETDATE()
    );

    -- Create indexes
    CREATE INDEX IX_Devices_Type ON [dbo].[Devices]([Type]);
    CREATE INDEX IX_Devices_Status ON [dbo].[Devices]([Status]);
    CREATE INDEX IX_Devices_MaEndDate ON [dbo].[Devices]([MaEndDate]);
    CREATE INDEX IX_Devices_Environment ON [dbo].[Devices]([Environment]);
END

IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='DeviceChanges' AND xtype='U')
BEGIN
    CREATE TABLE [dbo].[DeviceChanges] (
        [Id] INT IDENTITY(1,1) PRIMARY KEY,
        [DeviceId] INT NOT NULL,
        [ChangedAt] DATETIME2 DEFAULT GETDATE(),
        [Field] NVARCHAR(100) NOT NULL,
        [OldValue] NVARCHAR(MAX),
        [NewValue] NVARCHAR(MAX),
        [UserId] NVARCHAR(100),
        [ChangeReason] NVARCHAR(255),
        FOREIGN KEY ([DeviceId]) REFERENCES [dbo].[Devices]([Id])
    );

    -- Create indexes
    CREATE INDEX IX_DeviceChanges_DeviceId ON [dbo].[DeviceChanges]([DeviceId]);
    CREATE INDEX IX_DeviceChanges_ChangedAt ON [dbo].[DeviceChanges]([ChangedAt]);
    CREATE INDEX IX_DeviceChanges_Field ON [dbo].[DeviceChanges]([Field]);
END

-- Create useful views for AI queries
IF EXISTS (SELECT * FROM sys.views WHERE name = 'v_MA_Expired')
    DROP VIEW [dbo].[v_MA_Expired];
GO

CREATE VIEW [dbo].[v_MA_Expired] AS
SELECT 
    [Id],
    [Name],
    [SerialNumber],
    [Type],
    [MaEndDate],
    [MaCost],
    [Environment],
    [Owner],
    DATEDIFF(day, [MaEndDate], GETDATE()) as DaysExpired
FROM [dbo].[Devices]
WHERE [MaEndDate] < GETDATE()
    AND [Status] = 'Active';
GO

IF EXISTS (SELECT * FROM sys.views WHERE name = 'v_MA_Expiring_Soon')
    DROP VIEW [dbo].[v_MA_Expiring_Soon];
GO

CREATE VIEW [dbo].[v_MA_Expiring_Soon] AS
SELECT 
    [Id],
    [Name],
    [SerialNumber],
    [Type],
    [MaEndDate],
    [MaCost],
    [Environment],
    [Owner],
    DATEDIFF(day, GETDATE(), [MaEndDate]) as DaysUntilExpiry
FROM [dbo].[Devices]
WHERE [MaEndDate] BETWEEN GETDATE() AND DATEADD(day, 90, GETDATE())
    AND [Status] = 'Active';
GO

IF EXISTS (SELECT * FROM sys.views WHERE name = 'v_Device_Summary')
    DROP VIEW [dbo].[v_Device_Summary];
GO

CREATE VIEW [dbo].[v_Device_Summary] AS
SELECT 
    [Type],
    COUNT(*) as TotalDevices,
    SUM(CASE WHEN [Status] = 'Active' THEN 1 ELSE 0 END) as ActiveDevices,
    SUM(CASE WHEN [MaEndDate] < GETDATE() THEN 1 ELSE 0 END) as ExpiredMA,
    SUM(CASE WHEN [MaEndDate] BETWEEN GETDATE() AND DATEADD(day, 30, GETDATE()) THEN 1 ELSE 0 END) as ExpiringSoon,
    AVG([MaCost]) as AvgMACost,
    SUM([MaCost]) as TotalMACost,
    AVG([PurchaseCost]) as AvgPurchaseCost,
    SUM([PurchaseCost]) as TotalPurchaseCost
FROM [dbo].[Devices]
GROUP BY [Type];
GO

IF EXISTS (SELECT * FROM sys.views WHERE name = 'v_Recent_Changes')
    DROP VIEW [dbo].[v_Recent_Changes];
GO

CREATE VIEW [dbo].[v_Recent_Changes] AS
SELECT TOP 1000
    dc.[Id],
    dc.[ChangedAt],
    d.[Name] as DeviceName,
    d.[SerialNumber],
    d.[Type] as DeviceType,
    dc.[Field],
    dc.[OldValue],
    dc.[NewValue],
    dc.[UserId],
    dc.[ChangeReason]
FROM [dbo].[DeviceChanges] dc
INNER JOIN [dbo].[Devices] d ON dc.[DeviceId] = d.[Id]
ORDER BY dc.[ChangedAt] DESC;
GO

-- Create readonly user for AI Lambda
IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE name = 'cmdb_ai_readonly')
BEGIN
    CREATE LOGIN [cmdb_ai_readonly] WITH PASSWORD = 'AI_ReadOnly_Password_123!';
END

USE [CMDB];
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'cmdb_ai_readonly')
BEGIN
    CREATE USER [cmdb_ai_readonly] FOR LOGIN [cmdb_ai_readonly];
END

-- Grant read permissions
GRANT SELECT ON [dbo].[Devices] TO [cmdb_ai_readonly];
GRANT SELECT ON [dbo].[DeviceChanges] TO [cmdb_ai_readonly];
GRANT SELECT ON [dbo].[v_MA_Expired] TO [cmdb_ai_readonly];
GRANT SELECT ON [dbo].[v_MA_Expiring_Soon] TO [cmdb_ai_readonly];
GRANT SELECT ON [dbo].[v_Device_Summary] TO [cmdb_ai_readonly];
GRANT SELECT ON [dbo].[v_Recent_Changes] TO [cmdb_ai_readonly];

-- Insert sample data for testing
INSERT INTO [dbo].[Devices] (
    [Name], [SerialNumber], [Type], [Status], [Environment], [Owner], [Location],
    [MaStartDate], [MaEndDate], [MaCost], [PurchaseDate], [PurchaseCost], 
    [Vendor], [Model], [Description]
) VALUES 
('WEB-SERVER-01', 'WS001-2023', 'Server', 'Active', 'Production', 'IT-Team', 'DataCenter-A',
 '2023-01-15', '2025-01-15', 5000.00, '2023-01-01', 25000.00, 'Dell', 'PowerEdge R750', 'Main web server'),

('DB-SERVER-01', 'DB001-2023', 'Database Server', 'Active', 'Production', 'DBA-Team', 'DataCenter-A',
 '2023-02-01', '2025-02-01', 8000.00, '2023-01-15', 45000.00, 'HPE', 'ProLiant DL380', 'Primary database server'),

('SWITCH-CORE-01', 'SW001-2022', 'Network Switch', 'Active', 'Production', 'Network-Team', 'DataCenter-A',
 '2022-06-01', '2024-12-31', 2000.00, '2022-05-15', 15000.00, 'Cisco', 'Catalyst 9300', 'Core network switch'),

('LAPTOP-DEV-01', 'LT001-2024', 'Laptop', 'Active', 'Development', 'John Doe', 'Office-Floor-3',
 '2024-03-01', '2025-03-01', 300.00, '2024-02-15', 1500.00, 'Lenovo', 'ThinkPad X1', 'Developer laptop'),

('FIREWALL-01', 'FW001-2023', 'Firewall', 'Active', 'Production', 'Security-Team', 'DataCenter-A',
 '2023-01-01', '2024-11-15', 3000.00, '2022-12-15', 12000.00, 'Palo Alto', 'PA-3220', 'Main firewall'),

('STORAGE-01', 'ST001-2022', 'Storage', 'Active', 'Production', 'IT-Team', 'DataCenter-A',
 '2022-01-01', '2024-10-30', 4000.00, '2021-12-01', 30000.00, 'NetApp', 'FAS2750', 'Primary storage system');

-- Insert some change history
INSERT INTO [dbo].[DeviceChanges] ([DeviceId], [Field], [OldValue], [NewValue], [UserId], [ChangeReason]) 
VALUES 
(1, 'Status', 'Maintenance', 'Active', 'admin', 'Maintenance completed'),
(2, 'MaCost', '7500.00', '8000.00', 'admin', 'Contract renewal'),
(3, 'Location', 'DataCenter-B', 'DataCenter-A', 'network_admin', 'Datacenter migration'),
(4, 'Owner', 'Jane Smith', 'John Doe', 'hr_admin', 'Employee transfer'),
(5, 'Status', 'Active', 'Maintenance', 'security_admin', 'Security update');

PRINT 'CMDB AI Assistant database schema and sample data created successfully!';
PRINT 'Readonly user: cmdb_ai_readonly';
PRINT 'Views created: v_MA_Expired, v_MA_Expiring_Soon, v_Device_Summary, v_Recent_Changes';
