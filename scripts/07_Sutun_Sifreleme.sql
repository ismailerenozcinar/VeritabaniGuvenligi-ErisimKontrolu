/* =========================================================
   07 - Sutun (Column) Seviyesinde Sifreleme
   Proje 3: Guvenlik ve Erisim Kontrolu
   -----------------------------------------
   TDE'den farki: TDE veritabani dosyasini korur, DBA ise
   SELECT ile yine kimlik/maas gorebilir. Sutun sifreleme ile
   TCKimlikNo, BrutMaas, NetMaas kolonlari VARBINARY olarak
   tutulur; yalnizca anahtara erisebilen kullanici OKUYABILIR.
   ========================================================= */

USE PersonelDB;
GO

-- ===========================
-- 1) Database Master Key
-- ===========================
IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
BEGIN
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Personel.DMK.Parola.123!';
    PRINT '  [OK] PersonelDB DMK olusturuldu.';
END
ELSE
    PRINT '  [INFO] PersonelDB DMK zaten mevcut.';
GO

-- ===========================
-- 2) Hassas veri sertifikasi
-- ===========================
IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'Sertifika_HassasVeri')
BEGIN
    CREATE CERTIFICATE Sertifika_HassasVeri
    WITH SUBJECT = 'Hassas veri sifreleme sertifikasi',
         EXPIRY_DATE = '2031-12-31';
    PRINT '  [OK] Sertifika_HassasVeri olusturuldu.';
END
GO

-- ===========================
-- 3) Simetrik anahtar
-- ===========================
IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = 'SimetrikAnahtar_Hassas')
BEGIN
    CREATE SYMMETRIC KEY SimetrikAnahtar_Hassas
    WITH ALGORITHM = AES_256
    ENCRYPTION BY CERTIFICATE Sertifika_HassasVeri;
    PRINT '  [OK] SimetrikAnahtar_Hassas olusturuldu (AES_256).';
END
GO

-- ===========================
-- 4) Anahtari ac - SIFRELEME / COZME oncesi gereklidir
-- ===========================
OPEN SYMMETRIC KEY SimetrikAnahtar_Hassas
    DECRYPTION BY CERTIFICATE Sertifika_HassasVeri;
GO

-- ===========================
-- 5) TCKimlikNo'yu gercek sifreli degerlerle guncelle
--    (02 scriptinde 0x00 placeholder doldurulmustu)
-- ===========================
UPDATE ik.Calisanlar
SET TCKimlikNo = EncryptByKey(
    Key_GUID('SimetrikAnahtar_Hassas'),
    -- Ornek TC: CalisanID tabanli 11 haneli deterministik uretim
    CAST(
        RIGHT('00000000000' + CAST(10000000000 + (CalisanID * 37) % 89999999999 AS VARCHAR(11)), 11)
        AS NVARCHAR(11)
    )
);
GO

-- ===========================
-- 6) BrutMaas ve NetMaas sifrele
-- ===========================
UPDATE bordro.Maaslar
SET BrutMaas = EncryptByKey(
        Key_GUID('SimetrikAnahtar_Hassas'),
        CAST(25000 + (CalisanID % 30) * 1500 AS NVARCHAR(20))
    ),
    NetMaas  = EncryptByKey(
        Key_GUID('SimetrikAnahtar_Hassas'),
        CAST( (25000 + (CalisanID % 30) * 1500) * 0.78 AS NVARCHAR(20))
    );
GO

-- ===========================
-- 7) Sifreli hali goster (anlamsiz VARBINARY)
-- ===========================
PRINT '--- Sifreli hali (VARBINARY) ---';
SELECT TOP 3 CalisanID, Ad, Soyad, TCKimlikNo
FROM ik.Calisanlar;

SELECT TOP 3 MaasID, CalisanID, Donem, BrutMaas, NetMaas
FROM bordro.Maaslar;
GO

-- ===========================
-- 8) Cozulmus (aciliklanmis) hali - yetkili kullanici
-- ===========================
PRINT '--- Cozulmus hali (yetkili kullanici icin) ---';
SELECT TOP 5
    CalisanID, Ad, Soyad,
    CONVERT(NVARCHAR(11), DecryptByKey(TCKimlikNo)) AS TCKimlikNo_Acik
FROM ik.Calisanlar;

SELECT TOP 5
    m.MaasID, c.Ad, c.Soyad, m.Donem,
    CONVERT(NVARCHAR(20), DecryptByKey(m.BrutMaas)) AS Brut_Acik,
    CONVERT(NVARCHAR(20), DecryptByKey(m.NetMaas))  AS Net_Acik
FROM bordro.Maaslar m
JOIN ik.Calisanlar c ON c.CalisanID = m.CalisanID
ORDER BY m.MaasID;
GO

-- Anahtari kapat
CLOSE SYMMETRIC KEY SimetrikAnahtar_Hassas;
GO

-- ===========================
-- 9) Yetkisiz kullanici denemesi (anahtari acamaz -> NULL doner)
-- ===========================
PRINT '--- Yetkisiz kullanici denemesi (bordroUser icin TC NULL olmali) ---';
EXECUTE AS USER = 'bordroUser';
    -- bordroUser'a anahtar/sertifika uzerinde CONTROL yok
    BEGIN TRY
        OPEN SYMMETRIC KEY SimetrikAnahtar_Hassas
            DECRYPTION BY CERTIFICATE Sertifika_HassasVeri;
        PRINT '  [HATA] bordroUser anahtari acabildi (beklenmiyordu)';
        CLOSE SYMMETRIC KEY SimetrikAnahtar_Hassas;
    END TRY
    BEGIN CATCH
        PRINT '  [OK] bordroUser anahtari acamadi: ' + ERROR_MESSAGE();
    END CATCH;
REVERT;
GO

-- ===========================
-- 10) Ilgili kullanicilara anahtar erisimi (opsiyonel)
--     adminUser yetkili olsun, digerleri olmasin
-- ===========================
GRANT VIEW DEFINITION ON SYMMETRIC KEY::SimetrikAnahtar_Hassas TO adminUser;
GRANT CONTROL         ON CERTIFICATE::Sertifika_HassasVeri   TO adminUser;
GO

PRINT '>> Sutun sifreleme tamamlandi. TCKimlikNo, BrutMaas, NetMaas artik VARBINARY olarak sifreli.';
GO
