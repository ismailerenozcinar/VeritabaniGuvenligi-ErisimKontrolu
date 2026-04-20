/* =========================================================
   01 - PersonelDB Olusturma ve Semasi
   Proje 3: Guvenlik ve Erisim Kontrolu
   -----------------------------------------
   Hassas veri iceren (TC kimlik, maas, iletisim) ozgun bir
   personel takip veritabani. Sema; sifreleme, yetki ve audit
   demolarina uygun olacak sekilde tasarlandi.
   ========================================================= */

USE master;
GO

IF DB_ID(N'PersonelDB') IS NOT NULL
BEGIN
    ALTER DATABASE PersonelDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE PersonelDB;
END
GO

CREATE DATABASE PersonelDB;
GO

USE PersonelDB;
GO

-- Yetki demolari icin ayri sema'lar (hassas veri ayri sema'da)
CREATE SCHEMA ik       AUTHORIZATION dbo;   -- insan kaynaklari tablolari
GO
CREATE SCHEMA bordro   AUTHORIZATION dbo;   -- maas ve ozluk
GO
CREATE SCHEMA raporlama AUTHORIZATION dbo;  -- raporlama view'lari
GO

-- ===========================
-- Tablolar
-- ===========================

CREATE TABLE ik.Departmanlar (
    DepartmanID   INT IDENTITY(1,1) PRIMARY KEY,
    Ad            NVARCHAR(80)  NOT NULL UNIQUE,
    MerkezSehir   NVARCHAR(60)  NULL
);

CREATE TABLE ik.Unvanlar (
    UnvanID       INT IDENTITY(1,1) PRIMARY KEY,
    Ad            NVARCHAR(80)  NOT NULL UNIQUE,
    Seviye        TINYINT       NOT NULL    -- 1..5
);

CREATE TABLE ik.Calisanlar (
    CalisanID       INT IDENTITY(1000,1) PRIMARY KEY,
    TCKimlikNo      VARBINARY(256) NOT NULL,   -- sutun sifrelemeli
    Ad              NVARCHAR(80)  NOT NULL,
    Soyad           NVARCHAR(80)  NOT NULL,
    Email           NVARCHAR(120) NULL UNIQUE,
    Telefon         VARCHAR(20)   NULL,
    DepartmanID     INT           NOT NULL REFERENCES ik.Departmanlar(DepartmanID),
    UnvanID         INT           NOT NULL REFERENCES ik.Unvanlar(UnvanID),
    IseBaslama      DATE          NOT NULL,
    Aktif           BIT           NOT NULL DEFAULT 1
);

CREATE TABLE bordro.Maaslar (
    MaasID          INT IDENTITY(1,1) PRIMARY KEY,
    CalisanID       INT NOT NULL REFERENCES ik.Calisanlar(CalisanID),
    BrutMaas        VARBINARY(256) NOT NULL,   -- sutun sifrelemeli
    NetMaas         VARBINARY(256) NOT NULL,   -- sutun sifrelemeli
    Donem           CHAR(7) NOT NULL,          -- 'YYYY-MM'
    OdemeTarihi     DATE NULL,
    UNIQUE (CalisanID, Donem)
);

CREATE TABLE bordro.IzinTalepleri (
    IzinID          INT IDENTITY(1,1) PRIMARY KEY,
    CalisanID       INT NOT NULL REFERENCES ik.Calisanlar(CalisanID),
    BaslangicTarihi DATE NOT NULL,
    BitisTarihi     DATE NOT NULL,
    Aciklama        NVARCHAR(255) NULL,
    Durum           NVARCHAR(20) NOT NULL DEFAULT N'Beklemede'  -- Beklemede/Onay/Ret
);

-- Indeksler
CREATE INDEX IX_Calisanlar_DepartmanID ON ik.Calisanlar(DepartmanID);
CREATE INDEX IX_Calisanlar_UnvanID     ON ik.Calisanlar(UnvanID);
CREATE INDEX IX_Maaslar_Donem          ON bordro.Maaslar(Donem);
GO

PRINT '>> PersonelDB ve tablolari olusturuldu (ik, bordro, raporlama sema''lari dahil).';
GO
