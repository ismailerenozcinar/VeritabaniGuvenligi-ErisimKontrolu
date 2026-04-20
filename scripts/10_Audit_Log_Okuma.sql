/* =========================================================
   10 - Audit Log Okuma ve Analiz
   Proje 3: Guvenlik ve Erisim Kontrolu
   -----------------------------------------
   .sqlaudit dosyalari sys.fn_get_audit_file ile okunur.
   Bu script son 24 saatteki olaylari filtreler ve ozetler.
   ========================================================= */

USE PersonelDB;
GO

-- ===========================
-- 1) En son 50 olay - ham hali
-- ===========================
PRINT N'--- 1) En son 50 audit olayi ---';
SELECT TOP 50
    event_time,
    action_id,
    succeeded,
    server_principal_name   AS login_adi,
    database_principal_name AS db_user,
    database_name,
    schema_name,
    object_name,
    COALESCE(LEFT(statement, 300), '') AS ifade
FROM sys.fn_get_audit_file('C:\SQL_Audit\*.sqlaudit', DEFAULT, DEFAULT)
ORDER BY event_time DESC;
GO

-- ===========================
-- 2) Basarisiz loginler
-- ===========================
PRINT N'--- 2) Basarisiz loginler ---';
SELECT
    event_time,
    server_principal_name,
    client_ip,
    application_name
FROM sys.fn_get_audit_file('C:\SQL_Audit\*.sqlaudit', DEFAULT, DEFAULT)
WHERE action_id IN ('LGIF')    -- Login FAILED
ORDER BY event_time DESC;
GO

-- ===========================
-- 3) Basarili loginler (son 10)
-- ===========================
PRINT N'--- 3) Son basarili loginler ---';
SELECT TOP 10
    event_time,
    server_principal_name,
    client_ip,
    application_name
FROM sys.fn_get_audit_file('C:\SQL_Audit\*.sqlaudit', DEFAULT, DEFAULT)
WHERE action_id IN ('LGIS')    -- Login SUCCEEDED
ORDER BY event_time DESC;
GO

-- ===========================
-- 4) Hassas tablolara SELECT yapanlar
-- ===========================
PRINT N'--- 4) bordro.Maaslar uzerindeki erisimler ---';
SELECT
    event_time,
    server_principal_name AS login_adi,
    database_principal_name AS db_user,
    action_id,
    succeeded,
    LEFT(statement, 200) AS ifade
FROM sys.fn_get_audit_file('C:\SQL_Audit\*.sqlaudit', DEFAULT, DEFAULT)
WHERE object_name = 'Maaslar'
  AND schema_name = 'bordro'
ORDER BY event_time DESC;
GO

-- ===========================
-- 5) Kullanici bazli ozet
-- ===========================
PRINT N'--- 5) Kullanici bazli olay sayimi ---';
SELECT
    COALESCE(database_principal_name, server_principal_name) AS kullanici,
    action_id,
    COUNT(*) AS olay_sayisi
FROM sys.fn_get_audit_file('C:\SQL_Audit\*.sqlaudit', DEFAULT, DEFAULT)
WHERE event_time > DATEADD(HOUR, -24, SYSDATETIME())
GROUP BY COALESCE(database_principal_name, server_principal_name), action_id
ORDER BY olay_sayisi DESC;
GO

-- ===========================
-- 6) Basarisiz (izin verilmeyen) erisim denemeleri
-- ===========================
PRINT N'--- 6) Basarisiz erisim denemeleri ---';
SELECT
    event_time,
    COALESCE(database_principal_name, server_principal_name) AS kullanici,
    action_id,
    schema_name + '.' + object_name AS hedef,
    LEFT(statement, 200) AS ifade
FROM sys.fn_get_audit_file('C:\SQL_Audit\*.sqlaudit', DEFAULT, DEFAULT)
WHERE succeeded = 0
ORDER BY event_time DESC;
GO

PRINT '>> Audit log analizi tamamlandi.';
GO
