#!/bin/sh
#install.sh -- restore demo website to initial state

SOURCE=/home/bernie/Code/Onsite
TARGET=/home/bernie/Webdev/onsite
LIB=$SOURCE/lib

cd $SOURCE
rm -rf $TARGET
cp -R site $TARGET
cp scripts/editor.pl $TARGET/editor.cgi
chmod +x $TARGET/editor.cgi
ln -s $SOURCE/templates $TARGET/Templates
ln -s $LIB $TARGET/Lib
#chgrp webmast ../index.html
#chmod 664 ../index.html
#cp style.css ../style.css
#chgrp webmast ../style.css
#chmod 644 ../style.css
