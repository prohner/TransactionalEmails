print @@servername
print '$(datestamp)'

print 'Flagging records with datestamp'
update gc.dbo.TransactionEmail 
   set DateProcessed = '$(datestamp)' 
 where DateProcessed is null 

print 'Flagging records with datestamp'
update gc.dbo.TransactionEmailTest 
   set DateProcessed = '$(datestamp)' 
 where DateProcessed is null 
