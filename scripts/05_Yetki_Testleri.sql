/* =========================================================
   05 - Yetki Testleri (EXECUTE AS)
   Proje 3: Guvenlik ve Erisim Kontrolu
   -----------------------------------------
   4 kullanicinin da yetkilerini TEST eder. Login'e gecmek
   gerekmiyor; "EXECUTE AS USER = '...'" ile o kullanici kimligini
   gecici olarak ustleniriz. REVERT ile geri doneriz.
   ========================================================= */

USE PersonelDB;
GO

-- ===========================
-- Test 1: bordroUser - Maaslar OKUYABILMELI, TCKimlikNo GOREMEMELI
-- ===========================
PRINT N'--- Test 1: bordroUser ---';
EXECUTE AS USER = 'bordroUser';
    SELECT TOP 3 CalisanID, Donem FROM bordro.Maaslar;   -- OK
    BEGIN TRY
        SELECT TOP 1 TCKimlikNo FROM ik.Calisanlar;     -- DENY -> hata
        PRINT '  [HATA] TCKimlikNo okunabildi (beklenmiyordu)';
    END TRY
    BEGIN CATCH
        PRINT '  [OK] TCKimlikNo okunamadi: ' + ERROR_MESSAGE();
    END CATCH;
REVERT;
GO

-- ===========================
-- Test 2: ikUser - Calisanlar OKUMA/GUNCELLEME, Maaslar DENY
-- ===========================
PRINT N'--- Test 2: ikUser ---';
EXECUTE AS USER = 'ikUser';
    SELECT TOP 3 CalisanID, Ad, Soyad FROM ik.Calisanlar;  -- OK
    BEGIN TRY
        SELECT TOP 1 * FROM bordro.Maaslar;                -- DENY
        PRINT '  [HATA] Maaslar okundu (beklenmiyordu)';
    END TRY
    BEGIN CATCH
        PRINT '  [OK] Maaslar okunamadi: ' + ERROR_MESSAGE();
    END CATCH;
REVERT;
GO

-- ===========================
-- Test 3: raporUser - Sadece VIEW'dan raporlayabilmeli
-- ===========================
PRINT N'--- Test 3: raporUser ---';
EXECUTE AS USER = 'raporUser';
    SELECT TOP 3 * FROM raporlama.vwCalisanOzet;           -- OK
    BEGIN TRY
        SELECT TOP 1 BrutMaas FROM bordro.Maaslar;         -- kolon DENY
        PRINT '  [HATA] BrutMaas okundu';
    END TRY
    BEGIN CATCH
        PRINT '  [OK] BrutMaas okunamadi: ' + ERROR_MESSAGE();
    END CATCH;
    BEGIN TRY
        INSERT INTO ik.Departmanlar (Ad) VALUES (N'TestDept'); -- INSERT yok
        PRINT '  [HATA] INSERT kabul edildi';
    END TRY
    BEGIN CATCH
        PRINT '  [OK] INSERT reddedildi: ' + ERROR_MESSAGE();
    END CATCH;
REVERT;
GO

-- ===========================
-- Test 4: adminUser - Her sey OK
-- ===========================
PRINT N'--- Test 4: adminUser ---';
EXECUTE AS USER = 'adminUser';
    SELECT TOP 3 CalisanID, Ad FROM ik.Calisanlar;         -- OK
    BEGIN TRY
        INSERT INTO ik.Departmanlar (Ad, MerkezSehir)
        VALUES (N'Ar-Ge', N'Ankara');
        PRINT '  [OK] Admin INSERT basarili.';
        DELETE FROM ik.Departmanlar WHERE Ad = N'Ar-Ge';   -- geri al
    END TRY
    BEGIN CATCH
        PRINT '  [HATA] Admin bile INSERT yapamadi: ' + ERROR_MESSAGE();
    END CATCH;
REVERT;
GO

PRINT '>> Yetki testleri tamamlandi. Her "OK" satirin beklenen davranisi ifade eder.';
GO
