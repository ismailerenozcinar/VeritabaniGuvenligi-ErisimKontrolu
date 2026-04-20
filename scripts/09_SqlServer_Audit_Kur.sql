/* =========================================================
   09 - SQL Server Audit Kurulumu
   Proje 3: Guvenlik ve Erisim Kontrolu
   -----------------------------------------
   * Server Audit: kime/neye bakilacagini belirler, .sqlaudit
     dosyalarina yazar.
   * Database Audit Specification: hangi olaylarin (SELECT,
     UPDATE, DELETE, EXECUTE, login vs.) yakalanacagini tanimlar.
   ========================================================= */

-- Audit dosyalari icin klasor:
--   C:\SQL_Audit    (NT SERVICE\MSSQLSERVER yazma yetkisi gerekli)
-- Asagida xp_create_subdir ile otomatik olusturulur.

USE master;
GO

-- ===========================
-- 0) Audit klasorunu olustur (yoksa)
-- ===========================
BEGIN TRY
    EXEC master.sys.xp_create_subdir 'C:\SQL_Audit';
    PRINT '  [OK] C:\SQL_Audit klasoru hazir.';
END TRY
BEGIN CATCH
    PRINT '  [UYARI] C:\SQL_Audit olusturulamadi: ' + ERROR_MESSAGE();
    PRINT '  >> Lutfen klasoru elle olusturun ve NT SERVICE\MSSQLSERVER hesabina yazma yetkisi verin.';
END CATCH
GO

-- ===========================
-- 1) Varsa eski audit objelerini kapat/birak (idempotent)
-- ===========================
IF EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'ServerAuditSpec_PersonelDB')
BEGIN
    ALTER SERVER AUDIT SPECIFICATION ServerAuditSpec_PersonelDB WITH (STATE = OFF);
    DROP SERVER AUDIT SPECIFICATION ServerAuditSpec_PersonelDB;
END
GO

-- DB Audit Spec de Server Audit'e baglidir - once onu dusur
IF DB_ID('PersonelDB') IS NOT NULL
BEGIN
    DECLARE @drop NVARCHAR(MAX) = N'
        USE PersonelDB;
        IF EXISTS (SELECT 1 FROM sys.database_audit_specifications WHERE name = ''DBAuditSpec_PersonelDB'')
        BEGIN
            ALTER DATABASE AUDIT SPECIFICATION DBAuditSpec_PersonelDB WITH (STATE = OFF);
            DROP DATABASE AUDIT SPECIFICATION DBAuditSpec_PersonelDB;
        END';
    EXEC sp_executesql @drop;
END
GO

IF EXISTS (SELECT 1 FROM sys.server_audits WHERE name = 'Audit_PersonelDB')
BEGIN
    ALTER SERVER AUDIT Audit_PersonelDB WITH (STATE = OFF);
    DROP SERVER AUDIT Audit_PersonelDB;
END
GO

-- ===========================
-- 2) Server Audit objesi
-- ===========================
CREATE SERVER AUDIT Audit_PersonelDB
TO FILE (
    FILEPATH          = 'C:\SQL_Audit\',
    MAXSIZE           = 50 MB,
    MAX_ROLLOVER_FILES = 5,
    RESERVE_DISK_SPACE = OFF
)
WITH (
    QUEUE_DELAY = 1000,
    ON_FAILURE  = CONTINUE
);
GO

ALTER SERVER AUDIT Audit_PersonelDB WITH (STATE = ON);
GO

-- ===========================
-- 3) Server Audit Specification
--    - Basarili/basarisiz loginler
--    - Login degisiklikleri
-- ===========================
IF EXISTS (SELECT 1 FROM sys.server_audit_specifications WHERE name = 'ServerAuditSpec_PersonelDB')
BEGIN
    ALTER SERVER AUDIT SPECIFICATION ServerAuditSpec_PersonelDB WITH (STATE = OFF);
    DROP SERVER AUDIT SPECIFICATION ServerAuditSpec_PersonelDB;
END
GO

CREATE SERVER AUDIT SPECIFICATION ServerAuditSpec_PersonelDB
FOR SERVER AUDIT Audit_PersonelDB
    ADD (FAILED_LOGIN_GROUP),
    ADD (SUCCESSFUL_LOGIN_GROUP),
    ADD (SERVER_PRINCIPAL_CHANGE_GROUP)
WITH (STATE = ON);
GO

-- ===========================
-- 4) Database Audit Specification (PersonelDB icinde)
--    Hassas tablolara her tur erisim loglanir
-- ===========================
USE PersonelDB;
GO

IF EXISTS (SELECT 1 FROM sys.database_audit_specifications WHERE name = 'DBAuditSpec_PersonelDB')
BEGIN
    ALTER DATABASE AUDIT SPECIFICATION DBAuditSpec_PersonelDB WITH (STATE = OFF);
    DROP DATABASE AUDIT SPECIFICATION DBAuditSpec_PersonelDB;
END
GO

CREATE DATABASE AUDIT SPECIFICATION DBAuditSpec_PersonelDB
FOR SERVER AUDIT Audit_PersonelDB
    ADD (SELECT, INSERT, UPDATE, DELETE ON ik.Calisanlar        BY public),
    ADD (SELECT, INSERT, UPDATE, DELETE ON bordro.Maaslar       BY public),
    ADD (SELECT, INSERT, UPDATE, DELETE ON bordro.IzinTalepleri BY public),
    ADD (SCHEMA_OBJECT_PERMISSION_CHANGE_GROUP),
    ADD (DATABASE_ROLE_MEMBER_CHANGE_GROUP)
WITH (STATE = ON);
GO

-- ===========================
-- 5) Durumu listele
-- ===========================
SELECT name, is_state_enabled, create_date
FROM sys.server_audits;

SELECT name, is_state_enabled
FROM sys.server_audit_specifications;

SELECT name, is_state_enabled
FROM sys.database_audit_specifications;
GO

-- ===========================
-- 6) Audit uretmek icin birkac ornek islem
-- ===========================
PRINT '--- Ornek islemler (audit log uretmek icin) ---';

-- (a) bordroUser Calisanlar okur (TCKimlikNo haric)
EXECUTE AS USER = 'bordroUser';
    SELECT TOP 2 CalisanID, Ad, Soyad FROM ik.Calisanlar;
REVERT;

-- (b) ikUser Maaslar'i deniyor (DENY nedeniyle hata - yine loglanir)
EXECUTE AS USER = 'ikUser';
    BEGIN TRY
        SELECT TOP 1 * FROM bordro.Maaslar;
    END TRY BEGIN CATCH END CATCH;
REVERT;

-- (c) adminUser yeni bir departman ekler, sonra siler
EXECUTE AS USER = 'adminUser';
    INSERT INTO ik.Departmanlar (Ad, MerkezSehir) VALUES (N'AuditTest', N'Ankara');
    DELETE FROM ik.Departmanlar WHERE Ad = N'AuditTest';
REVERT;
GO

PRINT '>> Audit kuruldu, ornek kayitlar uretildi. 10 nolu script ile log okunabilir.';
GO
