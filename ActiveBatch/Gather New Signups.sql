use GCProd
go
print @@servername
declare @datestamp datetime = '$(datestamp)'
--declare @datestamp datetime = '2012-09-27 14:09:45'

print 'Pulling LIVE records from web02 and web02bal'
select 'web02' ServerSource, *
  into #new
  from web02.gc.dbo.TransactionEmail
 where DateProcessed = @datestamp
union 
select 'web02bal', *
  from web02bal.gc.dbo.TransactionEmail
 where DateProcessed = @datestamp

print 'Pulling TEST records from web02 and web02bal'
select 'web02' ServerSource, *
  into #newTest
  from web02.gc.dbo.TransactionEmailTest
 where DateProcessed = @datestamp
union 
select 'web02bal', *
  from web02bal.gc.dbo.TransactionEmailTest 
 where DateProcessed = @datestamp

/*
create table TransactionalEmail (
  ServerSource varchar(20),
  TransactionEmailId int,
  Contents varchar(max),
  IpAddress varchar(20),
  Datestamp datetime,
  DateProcessed datetime,
  DateProcessedForEmail datetime
)
create table TransactionalEmailTest (
  ServerSource varchar(20),
  TransactionEmailId int,
  Contents varchar(max),
  IpAddress varchar(20),
  Datestamp datetime,
  DateProcessed datetime,
  DateProcessedForEmail datetime
)
 */
--GCProd.dbo.WhooznxtSignups
--truncate table SingerSongWriter2012
--select * from SingerSongWriter2012

print 'Inserting into TransactionalEmail'
insert TransactionalEmail (ServerSource, TransactionEmailId, Contents, IpAddress, DateStamp, DateProcessed)
select *
  from #new

print 'Inserting into TransactionalEmailTest'
insert TransactionalEmailTest (ServerSource, TransactionEmailId, Contents, IpAddress, DateStamp, DateProcessed)
select *
  from #newTest

