/* =========================================================
   08 - SQL Injection Demolari
   Proje 3: Guvenlik ve Erisim Kontrolu
   -----------------------------------------
   1) Dinamik SQL (string concat) ile yazilmis GUVENSIZ stored proc
   2) sp_executesql + parametre ile yazilmis GUVENLI stored proc
   Ayni "saldiri" inputu ikisinde de denenir; sonuc farki gorulur.
   ========================================================= */

USE PersonelDB;
GO

-- ===========================
-- 1) GUVENSIZ prosedur (ogretici amacli - uretimde kullanmayin!)
-- ===========================
CREATE OR ALTER PROCEDURE ik.usp_CalisanBul_Guvensiz
    @Ad NVARCHAR(100)
AS
BEGIN
    DECLARE @sql NVARCHAR(MAX);
    -- KOTU: kullanici girdisi dogrudan SQL metnine yapistiriliyor
    SET @sql = N'SELECT CalisanID, Ad, Soyad, Email
                 FROM ik.Calisanlar
                 WHERE Ad = ''' + @Ad + N'''';
    PRINT '[GUVENSIZ SQL]: ' + @sql;
    EXEC sp_executesql @sql;
END
GO

-- ===========================
-- 2) GUVENLI prosedur (parametreli)
-- ===========================
CREATE OR ALTER PROCEDURE ik.usp_CalisanBul_Guvenli
    @Ad NVARCHAR(100)
AS
BEGIN
    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT CalisanID, Ad, Soyad, Email
        FROM ik.Calisanlar
        WHERE Ad = @p_Ad';
    PRINT '[GUVENLI SQL]: ' + @sql;
    EXEC sp_executesql
         @sql,
         N'@p_Ad NVARCHAR(100)',
         @p_Ad = @Ad;
END
GO

-- ===========================
-- 3) Normal kullanim - ikisi de ayni sonucu vermeli
-- ===========================
PRINT N'--- Normal kullanim: Ad = ''Ahmet'' ---';
EXEC ik.usp_CalisanBul_Guvensiz @Ad = N'Ahmet';
EXEC ik.usp_CalisanBul_Guvenli  @Ad = N'Ahmet';
GO

-- ===========================
-- 4) SALDIRI: classic 'OR 1=1' - tum satirlari dondurur
-- ===========================
PRINT N'--- SALDIRI 1: '' OR 1=1 -- ---';
PRINT N'Guvensiz:';
EXEC ik.usp_CalisanBul_Guvensiz @Ad = N''' OR 1=1 --';
PRINT N'Guvenli (sonuc bos olmali):';
EXEC ik.usp_CalisanBul_Guvenli  @Ad = N''' OR 1=1 --';
GO

-- ===========================
-- 5) SALDIRI: UNION ile maas tablosunu siza cikarma denemesi
-- ===========================
PRINT N'--- SALDIRI 2: UNION SELECT ile veri sizdirma ---';
PRINT N'Guvensiz (hata veya veri kacagi):';
BEGIN TRY
    EXEC ik.usp_CalisanBul_Guvensiz
         @Ad = N''' UNION SELECT CalisanID, CAST(Donem AS NVARCHAR), CAST(BrutMaas AS NVARCHAR), CAST(NetMaas AS NVARCHAR) FROM bordro.Maaslar --';
END TRY
BEGIN CATCH
    PRINT '  Hata: ' + ERROR_MESSAGE();
END CATCH;

PRINT N'Guvenli (sadece Ad = tam string ararur, sonuc bos):';
EXEC ik.usp_CalisanBul_Guvenli
     @Ad = N''' UNION SELECT CalisanID, CAST(Donem AS NVARCHAR), CAST(BrutMaas AS NVARCHAR), CAST(NetMaas AS NVARCHAR) FROM bordro.Maaslar --';
GO

-- ===========================
-- 6) SALDIRI: DROP TABLE denemesi (batch separator)
--    NOT: sp_executesql ile calisir, normal kullanicida yetkisi yoksa
--    hata doner; yine de demo icin gosterildi.
-- ===========================
PRINT N'--- SALDIRI 3: ''; DROP TABLE ik.Unvanlar -- ---';
PRINT N'Guvensiz dener (yetki yetmezse hata):';
BEGIN TRY
    EXEC ik.usp_CalisanBul_Guvensiz @Ad = N'x''; DROP TABLE ik.Unvanlar; --';
END TRY
BEGIN CATCH
    PRINT '  [Beklenen] hata: ' + ERROR_MESSAGE();
END CATCH;

PRINT N'Guvenli (komut calismaz, DROP yapilmaz):';
EXEC ik.usp_CalisanBul_Guvenli @Ad = N'x''; DROP TABLE ik.Unvanlar; --';
GO

-- Unvanlar tablosu hala var mi? (evet olmali)
SELECT COUNT(*) AS unvan_sayisi FROM ik.Unvanlar;
GO

PRINT '>> Injection demolari tamamlandi. Parametreli sorgular (sp_executesql) saldirilari notrler.';
GO
