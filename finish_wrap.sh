#!/bin/sh

echo

FreeSBIE=/usr/local/livefs

chflags -R noschg /tmp/ 2>/dev/null
rm -rf /tmp/* 2>/dev/null
rm -rf /tmp/root/*.* 2>/dev/null
rm -rf /tmp/cf/*.* 2>/dev/null
mkdir -p /tmp/root 2>/dev/null
mkdir -p /tmp/cf 2>/dev/null

umount /tmp/root 2>/dev/null
umount /tmp/cf 2>/dev/null
mdconfig -d -u 91 2>/dev/null

cd /home/sullrich

cp /home/sullrich/pfSense/boot/device.hints_wrap \
        /usr/local/livefs/boot/device.hints
cp /home/sullrich/pfSense/boot/loader.conf_wrap \
        /usr/local/livefs/boot/loader.conf
cp /home/sullrich/pfSense/etc/ttys_wrap \
	/usr/local/livefs/etc/

mkdir  $FreeSBIE/dev 2>/dev/null
rm -f $FreeSBIE/etc/rc.d/freesbie_1st 2>/dev/null
rm -f $FreeSBIE/usr/local/share/freesbie/files/000.freesbie_2nd.sh 2>/dev/null
rm -rf $FreeSBIE/cloop 2>/dev/null
rm -rf $FreeSBIE/dist 2>/dev/null
rm -f $FreeSBIE/etc/rc.local 2>/dev/null
rm $FreeSBIE/root/.tcshrc 2>/dev/null
rm $FreeSBIE/root/.message* 2>/dev/null
rm $FreeSBIE/etc/rc.conf 2>/dev/null
touch $FreeSBIE/etc/rc.conf 2>/dev/null

# Prevent the system from asking for these twice
touch $FreeSBIE/root/.part_mount 
touch $FreeSBIE/root/.first_time

echo > $FreeSBIE/etc/motd
echo /etc/rc.initial > $FreeSBIE/root/.shrc
echo exit >> $FreeSBIE/root/.shrc
rm -f $FreeSBIE/usr/local/bin/after_installation_routines.sh 2>/dev/null

cd /home/sullrich/tools
echo Calculating size of /usr/local/livefs...
du -H -d0 /usr/local/livefs
cd /home/sullrich/tools

echo Running DD
/bin/dd if=/dev/zero of=image.bin bs=1k count=111072
echo Running mdconfig
/sbin/mdconfig -a -t vnode -u91 -f image.bin
disklabel -BR md91 /home/sullrich/pfSense/boot/label.proto_wrap

echo Running newfs
newfs /dev/md91a
newfs /dev/md91d

echo -n "Mounting -> [ /tmp/root "
mount /dev/md91a /tmp/root
echo -n "/tmp/cf "
mount /dev/md91d /tmp/cf
echo "]"
echo -n "Populating /tmp/root -> [ "
echo -n "livefs "
cd /usr/local/livefs/ && tar czPf /home/sullrich/livefs.tgz .
cd /tmp/root && tar xzPf /home/sullrich/livefs.tgz
echo -n "pfSense "
cd /home/sullrich/pfSense && tar czPf /home/sullrich/pfSense.tgz .
cd /tmp/root && tar xzPf /home/sullrich/pfSense.tgz
echo "]"

echo /dev/ad0		/		ufs	ro		1 \
	1 > /tmp/root/etc/fstab
echo /dev/ad0a		/cf		ufs	ro		1 \
	1 >> /tmp/root/etc/fstab
echo md			/tmp		mfs	rw,-s4m		1 \
	1 >> /tmp/root/etc/fstab

mv /tmp/root/cf /tmp/cf/
echo -n "Config directory: "
ls /tmp/cf/cf/conf

rm -rf /tmp/root/var/run
rm -rf /tmp/root/var/log
rm -rf /tmp/root/var/etc
rm -rf /tmp/root/var/tmp

# setup symlinks
echo "#!/bin/sh" > /tmp/root/script
echo "ln -s /tmp /var/tmp" >> /tmp/root/script
echo "ln -s /tmp /var/run" >> /tmp/root/script
echo "ln -s /tmp /var/etc" >> /tmp/root/script
echo "ln -s /tmp /var/log" >> /tmp/root/script
echo "ln -s /cf/conf /conf" >> /tmp/root/script
chmod a+x /tmp/root/script
chroot /tmp/root/ /script

cd /home/sullrich/tools && umount /tmp/root
cd /home/sullrich/tools && umount /tmp/cf
/sbin/mdconfig -d -u 91

echo gzipping image.bin
gzip -9 image.bin
mv image.bin.gz pfSense-128-megs.bin.gz
echo -n "Image size: "
ls -la pfSense-128-megs.bin.gz

echo Cleaning up /tmp/
rm -rf /tmp/root
rm -rf /tmp/cf

