/* =========================================================
   11 - Guvenlik Durumu Raporu
   Proje 3: Guvenlik ve Erisim Kontrolu
   -----------------------------------------
   Tek tiklamayla PersonelDB guvenlik duruminu ozetler:
   - Login/User listesi
   - Rol uyelikleri
   - Yetkiler (GRANT/DENY)
   - TDE durumu
   - Sertifika ve simetrik anahtarlar
   - Audit konfigurasyonu
   ========================================================= */

USE PersonelDB;
GO

PRINT N'===========================================';
PRINT N'  PERSONELDB GUVENLIK DURUMU RAPORU';
PRINT N'===========================================';
GO

-- 1) Sunucu seviyesi loginler
PRINT N'--- 1) Sunucu seviyesi loginler ---';
SELECT
    sp.name              AS login_adi,
    sp.type_desc         AS tip,
    sp.is_disabled       AS kapali_mi,
    sp.create_date       AS olusturulma,
    LOGINPROPERTY(sp.name, 'PasswordLastSetTime') AS parola_son_degisim
FROM sys.server_principals sp
WHERE sp.name IN ('adminUser','bordroUser','ikUser','raporUser');
GO

-- 2) Database kullanicilari
PRINT N'--- 2) PersonelDB database kullanicilari ---';
SELECT
    dp.name,
    dp.type_desc,
    dp.authentication_type_desc,
    dp.create_date
FROM sys.database_principals dp
WHERE dp.type IN ('S','U','G')
  AND dp.name NOT IN ('dbo','guest','INFORMATION_SCHEMA','sys','public');
GO

-- 3) Rol uyelikleri
PRINT N'--- 3) Rol uyelikleri ---';
SELECT
    r.name AS rol,
    m.name AS uye
FROM sys.database_role_members rm
JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
JOIN sys.database_principals m ON m.principal_id = rm.member_principal_id
WHERE r.name LIKE 'rol_%'
ORDER BY r.name, m.name;
GO

-- 4) GRANT / DENY ozeti
PRINT N'--- 4) Izinler (GRANT/DENY) ---';
SELECT
    dp.name                                AS kime,
    perm.state_desc                        AS durum,
    perm.permission_name                   AS izin,
    perm.class_desc                        AS sinif,
    CASE perm.class
        WHEN 0 THEN DB_NAME()
        WHEN 1 THEN OBJECT_SCHEMA_NAME(perm.major_id) + '.' + OBJECT_NAME(perm.major_id)
                    + CASE WHEN perm.minor_id <> 0
                           THEN ' (' + COL_NAME(perm.major_id, perm.minor_id) + ')'
                           ELSE '' END
        WHEN 3 THEN SCHEMA_NAME(perm.major_id)
        ELSE '(class=' + CAST(perm.class AS VARCHAR) + ')'
    END                                    AS hedef
FROM sys.database_permissions perm
JOIN sys.database_principals  dp ON dp.principal_id = perm.grantee_principal_id
WHERE dp.name LIKE 'rol_%' OR dp.name IN ('adminUser','bordroUser','ikUser','raporUser')
ORDER BY dp.name, perm.state_desc, izin;
GO

-- 5) TDE durumu
PRINT N'--- 5) TDE durumu ---';
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
FROM sys.dm_database_encryption_keys;
GO

-- 6) Sertifikalar ve simetrik anahtarlar
PRINT N'--- 6) Sertifikalar ---';
SELECT name, subject, expiry_date, start_date FROM sys.certificates;

PRINT N'--- 6b) Simetrik anahtarlar ---';
SELECT name, algorithm_desc, create_date FROM sys.symmetric_keys;
GO

-- 7) Audit konfigurasyonu
PRINT N'--- 7) Server Audits ---';
SELECT name, type_desc, is_state_enabled, create_date
FROM sys.server_audits;

PRINT N'--- 7b) Server Audit Specifications ---';
SELECT name, is_state_enabled
FROM sys.server_audit_specifications;

PRINT N'--- 7c) Database Audit Specifications ---';
SELECT name, is_state_enabled
FROM sys.database_audit_specifications;
GO

-- 8) Hassas kolonlarin durumu
PRINT N'--- 8) Hassas kolonlar (VARBINARY - sifreli) ---';
SELECT
    OBJECT_SCHEMA_NAME(c.object_id) + '.' + OBJECT_NAME(c.object_id) AS tablo,
    c.name        AS kolon,
    t.name        AS veri_tipi,
    c.max_length  AS uzunluk
FROM sys.columns c
JOIN sys.types   t ON t.user_type_id = c.user_type_id
WHERE OBJECT_SCHEMA_NAME(c.object_id) IN ('ik','bordro')
  AND t.name = 'varbinary';
GO

PRINT N'===========================================';
PRINT N'  RAPOR SONU';
PRINT N'===========================================';
GO
