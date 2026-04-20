/* =========================================================
   02 - Ornek Veri Ekleme
   Proje 3: Guvenlik ve Erisim Kontrolu
   -----------------------------------------
   NOT: TCKimlikNo ve BrutMaas/NetMaas sutunlari varbinary oldugu
   icin baslangicta DUMMY bytes ile doldurulur. 07 numarali
   scriptte (sutun sifreleme) bu sutunlar gercek sifreli degerlerle
   UPDATE edilecektir.
   ========================================================= */

USE PersonelDB;
GO

-- Departmanlar
INSERT INTO ik.Departmanlar (Ad, MerkezSehir) VALUES
(N'Yazilim Gelistirme',  N'Ankara'),
(N'Veri Muhendisligi',   N'Ankara'),
(N'Insan Kaynaklari',    N'Istanbul'),
(N'Bordro',              N'Istanbul'),
(N'Pazarlama',           N'Izmir'),
(N'Bilgi Guvenligi',     N'Ankara');

-- Unvanlar
INSERT INTO ik.Unvanlar (Ad, Seviye) VALUES
(N'Stajyer', 1),
(N'Uzman Yardimcisi', 2),
(N'Uzman', 3),
(N'Kidemli Uzman', 4),
(N'Yonetici', 5);
GO

-- Calisanlar (30 kisi) - TCKimlikNo placeholder olarak 0x00 doldurulur
DECLARE @i INT = 1;
DECLARE @isimler TABLE (Ad NVARCHAR(80), Soyad NVARCHAR(80));
INSERT INTO @isimler VALUES
(N'Ahmet',N'Yilmaz'),(N'Mehmet',N'Kaya'),(N'Ayse',N'Demir'),(N'Fatma',N'Celik'),
(N'Ali',N'Sahin'),(N'Zeynep',N'Koc'),(N'Mustafa',N'Arslan'),(N'Elif',N'Dogan'),
(N'Hasan',N'Kilic'),(N'Hatice',N'Aslan'),(N'Ibrahim',N'Yildiz'),(N'Emine',N'Polat'),
(N'Osman',N'Kurt'),(N'Havva',N'Erdogan'),(N'Yusuf',N'Aydin'),(N'Rabia',N'Ozdemir'),
(N'Kemal',N'Akin'),(N'Selin',N'Tas'),(N'Murat',N'Ozturk'),(N'Leyla',N'Avci'),
(N'Can',N'Ercan'),(N'Deniz',N'Soylu'),(N'Burak',N'Simsek'),(N'Seda',N'Ergun'),
(N'Emre',N'Korkmaz'),(N'Esra',N'Gunes'),(N'Oguz',N'Keskin'),(N'Pelin',N'Ogut'),
(N'Tolga',N'Tekin'),(N'Naz',N'Guler');

DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT Ad, Soyad FROM @isimler;

DECLARE @ad NVARCHAR(80), @soyad NVARCHAR(80);
OPEN cur;
FETCH NEXT FROM cur INTO @ad, @soyad;
WHILE @@FETCH_STATUS = 0
BEGIN
    INSERT INTO ik.Calisanlar
        (TCKimlikNo, Ad, Soyad, Email, Telefon,
         DepartmanID, UnvanID, IseBaslama, Aktif)
    VALUES
        (CONVERT(VARBINARY(256), REPLICATE('0',11)),   -- placeholder
         @ad, @soyad,
         LOWER(@ad) + '.' + LOWER(@soyad) + '@ornek.com',
         '0530-000-' + RIGHT('0000' + CAST(1000 + @i AS VARCHAR), 4),
         ((@i - 1) % 6) + 1,
         ((@i * 2) % 5) + 1,
         DATEADD(DAY, -@i * 40, '2026-04-20'),
         CASE WHEN @i % 10 = 0 THEN 0 ELSE 1 END);

    SET @i = @i + 1;
    FETCH NEXT FROM cur INTO @ad, @soyad;
END
CLOSE cur; DEALLOCATE cur;
GO

-- Maaslar (her calisan icin son 3 donem)
INSERT INTO bordro.Maaslar (CalisanID, BrutMaas, NetMaas, Donem, OdemeTarihi)
SELECT
    c.CalisanID,
    CONVERT(VARBINARY(256), REPLICATE('0',11)),   -- placeholder
    CONVERT(VARBINARY(256), REPLICATE('0',11)),   -- placeholder
    d.Donem,
    DATEFROMPARTS(LEFT(d.Donem,4), RIGHT(d.Donem,2), 28)
FROM ik.Calisanlar c
CROSS JOIN (VALUES ('2026-01'),('2026-02'),('2026-03')) AS d(Donem);
GO

-- Izin talepleri (bir kismi)
INSERT INTO bordro.IzinTalepleri (CalisanID, BaslangicTarihi, BitisTarihi, Aciklama, Durum)
SELECT TOP 12
    CalisanID,
    DATEADD(DAY, (CalisanID % 10), '2026-05-01'),
    DATEADD(DAY, (CalisanID % 10) + 5, '2026-05-01'),
    N'Yillik izin talebi',
    CASE CalisanID % 3 WHEN 0 THEN N'Onay' WHEN 1 THEN N'Beklemede' ELSE N'Ret' END
FROM ik.Calisanlar
ORDER BY CalisanID;
GO

PRINT '>> Ornek veriler yuklendi.';
PRINT '>> Departman : ' + CAST((SELECT COUNT(*) FROM ik.Departmanlar) AS VARCHAR);
PRINT '>> Unvan     : ' + CAST((SELECT COUNT(*) FROM ik.Unvanlar) AS VARCHAR);
PRINT '>> Calisan   : ' + CAST((SELECT COUNT(*) FROM ik.Calisanlar) AS VARCHAR);
PRINT '>> Maas      : ' + CAST((SELECT COUNT(*) FROM bordro.Maaslar) AS VARCHAR);
PRINT '>> Izin      : ' + CAST((SELECT COUNT(*) FROM bordro.IzinTalepleri) AS VARCHAR);
GO
