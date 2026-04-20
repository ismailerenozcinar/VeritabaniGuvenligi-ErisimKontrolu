/* =========================================================
   03 - Login ve User Yonetimi
   Proje 3: Guvenlik ve Erisim Kontrolu
   -----------------------------------------
   Login  (server seviyesinde) ile User (database seviyesinde) ayrimini,
   SQL Server Authentication ile calisan kullanici olusturmayi ve
   Windows Authentication aciklamasini icerir.
   ========================================================= */

USE master;
GO

-- Onceki calistirmalardan kalmis olabilecek loginleri temizle
DECLARE @lg NVARCHAR(128);
DECLARE c CURSOR LOCAL FAST_FORWARD FOR
    SELECT name FROM sys.server_principals
    WHERE name IN (N'adminUser', N'bordroUser', N'ikUser', N'raporUser');
OPEN c; FETCH NEXT FROM c INTO @lg;
WHILE @@FETCH_STATUS = 0
BEGIN
    DECLARE @d NVARCHAR(512) = N'DROP LOGIN [' + @lg + N']';
    BEGIN TRY EXEC sp_executesql @d; END TRY BEGIN CATCH END CATCH;
    FETCH NEXT FROM c INTO @lg;
END
CLOSE c; DEALLOCATE c;
GO

-- ===========================
-- SQL Server Authentication Login'leri olustur
-- (Uretimde parolalar gizli bir yerde tutulur; demo amaciyla burada)
-- ===========================
CREATE LOGIN adminUser   WITH PASSWORD = 'Admin.Parola.123!',
    CHECK_POLICY = ON, CHECK_EXPIRATION = OFF;
CREATE LOGIN bordroUser  WITH PASSWORD = 'Bordro.Parola.123!',
    CHECK_POLICY = ON, CHECK_EXPIRATION = OFF;
CREATE LOGIN ikUser      WITH PASSWORD = 'Ik.Parola.123!',
    CHECK_POLICY = ON, CHECK_EXPIRATION = OFF;
CREATE LOGIN raporUser   WITH PASSWORD = 'Rapor.Parola.123!',
    CHECK_POLICY = ON, CHECK_EXPIRATION = OFF;
GO

-- ===========================
-- PersonelDB icinde User olustur (login'lerle eslesik)
-- ===========================
USE PersonelDB;
GO

IF USER_ID('adminUser')  IS NOT NULL  DROP USER adminUser;
IF USER_ID('bordroUser') IS NOT NULL  DROP USER bordroUser;
IF USER_ID('ikUser')     IS NOT NULL  DROP USER ikUser;
IF USER_ID('raporUser')  IS NOT NULL  DROP USER raporUser;

CREATE USER adminUser   FOR LOGIN adminUser;
CREATE USER bordroUser  FOR LOGIN bordroUser;
CREATE USER ikUser      FOR LOGIN ikUser;
CREATE USER raporUser   FOR LOGIN raporUser;
GO

-- Kontrol sorgulari
SELECT sp.name AS login_name, sp.type_desc, sp.is_disabled, sp.create_date
FROM sys.server_principals sp
WHERE sp.name IN ('adminUser','bordroUser','ikUser','raporUser');

SELECT dp.name AS user_name, dp.type_desc, dp.authentication_type_desc
FROM sys.database_principals dp
WHERE dp.name IN ('adminUser','bordroUser','ikUser','raporUser');
GO

/* =========================================================
   NOT: Windows Authentication icin login boyle olusturulur:
     CREATE LOGIN [DOMAIN\KullaniciAdi] FROM WINDOWS;
   Domain ortami olmadigindan bu projede SQL Auth tercih edildi.
   SSMS'te Object Explorer'da "Logins" altinda tipler gorulebilir.
   ========================================================= */

PRINT '>> 4 adet SQL login ve database user''i hazir.';
GO
