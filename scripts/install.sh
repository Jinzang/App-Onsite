#!/bin/sh
#install.sh -- restore demo website to initial state

cd ~/Code/Onsite
rm -rf test
cp -R site test
cp scripts/editor.pl test/editor.cgi
chmod +x test/editor.cgi
ln -s ../templates test/Templates
ln -s ../lib test/Lib
#chgrp webmast ../index.html
#chmod 664 ../index.html
#cp style.css ../style.css
#chgrp webmast ../style.css
#chmod 644 ../style.css
