echo.
echo This should be run from ActiveBatch to avoid conflicts
echo Job: /Guitar Center/Email/Transactional Emails/Copy Test To Production
echo.

cd \GCNew\Email\TransactionalEmails

xcopy transactionalTest\* transactional /Y /S

copy /y OgreTest.bat Ogre.bat
