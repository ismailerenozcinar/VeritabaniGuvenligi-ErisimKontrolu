/* =========================================================
   00 - YARDIMCI: PersonelDB Oturumlarini Temizle
   Proje 3: Guvenlik ve Erisim Kontrolu
   -----------------------------------------
   "Cannot obtain exclusive access" / "database is in use" hatalarinda
   PersonelDB'ye bagli tum oturumlari (kendisi haric) kill eder.
   ========================================================= */

USE master;
GO

PRINT '--- PersonelDB uzerindeki aktif oturumlar ---';
SELECT s.session_id, s.login_name, s.host_name, s.program_name, s.status
FROM sys.dm_exec_sessions s
WHERE s.database_id = DB_ID(N'PersonelDB') AND s.session_id <> @@SPID;

DECLARE @sql NVARCHAR(MAX) = N'';
SELECT @sql = @sql + N'KILL ' + CAST(session_id AS NVARCHAR(10)) + N';' + CHAR(13)
FROM sys.dm_exec_sessions
WHERE database_id = DB_ID(N'PersonelDB') AND session_id <> @@SPID;

IF @sql = N''
    PRINT '>> Kilinecek oturum yok. DB serbest.';
ELSE
BEGIN
    PRINT '>> Kill komutlari:';  PRINT @sql;
    EXEC sp_executesql @sql;
    PRINT '>> Tum oturumlar sonlandirildi.';
END
GO
