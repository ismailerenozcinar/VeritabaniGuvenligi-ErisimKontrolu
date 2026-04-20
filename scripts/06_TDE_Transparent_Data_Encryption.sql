/* =========================================================
   06 - TDE (Transparent Data Encryption)
   Proje 3: Guvenlik ve Erisim Kontrolu
   -----------------------------------------
   TDE, veritabani dosyalarini (MDF/LDF) ve yedek (BAK) dosyalarini
   disk uzerinde sifreler. Uygulama tarafinda hic bir degisiklik
   gerektirmez; "transparent" olmasi da buradan gelir.
   Sertifika kaybedilirse veritabani geri yuklenemez - bu yuzden
   sertifikayi mutlaka yedekleyin (asagida BACKUP CERTIFICATE).
   ========================================================= */

USE master;
GO

-- ===========================
-- 1) Master Database Master Key (DMK)
-- ===========================
IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
BEGIN
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'MasterKey.Parola.123!';
    PRINT '  [OK] Master DMK olusturuldu.';
END
ELSE
    PRINT '  [INFO] Master DMK zaten mevcut.';
GO

-- ===========================
-- 2) TDE sertifikasi
-- ===========================
IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'TDE_Sertifika')
BEGIN
    CREATE CERTIFICATE TDE_Sertifika
    WITH SUBJECT = 'PersonelDB TDE Sertifikasi',
         EXPIRY_DATE = '2031-12-31';
    PRINT '  [OK] TDE_Sertifika olusturuldu.';
END
ELSE
    PRINT '  [INFO] TDE_Sertifika zaten mevcut.';
GO

-- ===========================
-- 3) Sertifikayi yedekle (cok onemli!)
--    .cer ve .pvk dosyalari repoya girmez (.gitignore)
-- ===========================
IF NOT EXISTS (SELECT 1 FROM sys.dm_os_file_exists('C:\SQL_Yedekler\TDE_Sertifika.cer'))
BEGIN
    BEGIN TRY
        BACKUP CERTIFICATE TDE_Sertifika
        TO FILE = 'C:\SQL_Yedekler\TDE_Sertifika.cer'
        WITH PRIVATE KEY (
            FILE     = 'C:\SQL_Yedekler\TDE_Sertifika.pvk',
            ENCRYPTION BY PASSWORD = 'Cert.Yedek.Parola.123!'
        );
        PRINT '  [OK] Sertifika C:\SQL_Yedekler icine yedeklendi.';
    END TRY
    BEGIN CATCH
        PRINT '  [UYARI] Sertifika yedeklenemedi (klasor yok olabilir): ' + ERROR_MESSAGE();
    END CATCH
END
GO

-- ===========================
-- 4) PersonelDB icin Database Encryption Key (DEK)
-- ===========================
USE PersonelDB;
GO

IF NOT EXISTS (SELECT 1 FROM sys.dm_database_encryption_keys WHERE database_id = DB_ID('PersonelDB'))
BEGIN
    CREATE DATABASE ENCRYPTION KEY
    WITH ALGORITHM = AES_256
    ENCRYPTION BY SERVER CERTIFICATE TDE_Sertifika;
    PRINT '  [OK] PersonelDB DEK olusturuldu (AES_256).';
END
ELSE
    PRINT '  [INFO] DEK zaten mevcut.';
GO

-- ===========================
-- 5) TDE'yi acik hale getir
-- ===========================
ALTER DATABASE PersonelDB SET ENCRYPTION ON;
GO

-- ===========================
-- 6) Durumu kontrol et
--    encryption_state:
--      0 = yok, 1 = sifrelenmemis, 2 = sifreleme basladi,
--      3 = sifreli, 4 = anahtar degisimi, 5 = sifresiz cozuluyor
-- ===========================
SELECT
    DB_NAME(database_id)                AS veritabani,
    encryption_state,
    CASE encryption_state
        WHEN 0 THEN 'Sifreleme yok'
        WHEN 1 THEN 'Sifrelenmemis'
        WHEN 2 THEN 'Sifreleme baslatildi'
        WHEN 3 THEN 'Sifreli'
        WHEN 4 THEN 'Anahtar degisimi'
        WHEN 5 THEN 'Sifresiz cozuluyor'
    END                                  AS durum,
    percent_complete,
    key_algorithm,
    key_length
FROM sys.dm_database_encryption_keys
WHERE database_id = DB_ID('PersonelDB');
GO

-- Tempdb de otomatik olarak sifrelenir (TDE yan etkisi)
SELECT DB_NAME(database_id) AS db, encryption_state
FROM sys.dm_database_encryption_keys;
GO

PRINT '>> TDE etkinlestirildi. Arka planda sifreleme devam edebilir;';
PRINT '>> encryption_state = 3 oldugunda islem tamamlanmis demektir.';
GO
