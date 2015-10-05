#!/bin/bash

ceph_bin="/usr/bin/ceph"
rados_bin="/usr/bin/rados"

# Initialising variables
# See: http://ceph.com/docs/master/rados/operations/pg-states/
creating=0
active=0
clean=0
down=0
replay=0
splitting=0
scrubbing=0
degraded=0
inconsistent=0
peering=0
repair=0
recovering=0
backfill=0
waitBackfill=0
incomplete=0
stale=0
remapped=0

# Get data
pginfo=$(echo -n "  pgmap $($ceph_bin pg stat)" | sed -n "s/.*pgmap/pgmap/p")
pgtotal=$(echo $pginfo | cut -d':' -f2 | sed 's/[^0-9]//g')
pgstats=$(echo $pginfo | cut -d':' -f3 | cut -d';' -f1| sed 's/ /\\ /g')
pggdegraded=$(echo $pginfo | sed -n '/degraded/s/.* degraded (\([^%]*\)%.*/\1/p')
if [[ "$pggdegraded" == "" ]]
then
  pggdegraded=0
fi
# unfound (0.004%)
pgunfound=$(echo $pginfo | cut -d';' -f2|sed -n '/unfound/s/.*unfound (\([^%]*\)%.*/\1/p')
if [[ "$pgunfound" == "" ]]
then
  pgunfound=0
fi

# write kbps B/s
rdbps=$(echo $pginfo | sed -n '/pgmap/s/.* \([0-9]* .\?\)B\/s rd.*/\1/p' | sed -e "s/K/*1000/ig;s/M/*1000*1000/i;s/G/*1000*1000*1000/i;s/E/*1000*1000*1000*1000/i" | bc)
if [[ "$rdbps" == "" ]]
then
  rdbps=0
fi

# write kbps B/s
wrbps=$(echo $pginfo | sed -n '/pgmap/s/.* \([0-9]* .\?\)B\/s wr.*/\1/p' | sed -e "s/K/*1000/ig;s/M/*1000*1000/i;s/G/*1000*1000*1000/i;s/E/*1000*1000*1000*1000/i" | bc)
if [[ "$wrbps" == "" ]]
then
  wrbps=0
fi

# ops
ops=$(echo $pginfo | sed -n '/pgmap/s/.* \([0-9]*\) op\/s.*/\1/p')
if [[ "$ops" == "" ]]
then
  ops=0
fi

# Explode array
IFS=', ' read -a array <<< "$pgstats"
for element in "${array[@]}"
do
    element=$(echo "$element" | sed 's/^ *//g')
    # Get elements
    number=$(echo $element | cut -d' ' -f1)
    data=$(echo $element | cut -d' ' -f2)

    # Agregate data
    if [ "$(echo $data | grep creating | wc -l)" == 1 ]
    then
	  creating=$(echo $creating+$number|bc)
    fi

    if [ "$(echo $data | grep active | wc -l)" == 1 ]
    then
	  active=$(echo $active+$number|bc)
    fi

    if [ "$(echo $data | grep clean | wc -l)" == 1 ]
    then
	  clean=$(echo $clean+$number|bc)
    fi

    if [ "$(echo $data | grep down | wc -l)" == 1 ]
    then
	  down=$(echo $down+$number|bc)
    fi

    if [ "$(echo $data | grep replay | wc -l)" == 1 ]
    then
	  replay=$(echo $replay+$number|bc)
    fi

    if [ "$(echo $data | grep splitting | wc -l)" == 1 ]
    then
	  splitting=$(echo $splitting+$number|bc)
    fi

    if [ "$(echo $data | grep scrubbing | wc -l)" == 1 ]
    then
	  scrubbing=$(echo $scrubbing+$number|bc)
    fi

    if [ "$(echo $data | grep degraded | wc -l)" == 1 ]
    then
	  degraded=$(echo $degraded+$number|bc)
    fi

    if [ "$(echo $data | grep inconsistent | wc -l)" == 1 ]
    then
	  inconsistent=$(echo $inconsistent+$number|bc)
    fi

    if [ "$(echo $data | grep peering | wc -l)" == 1 ]
    then
	  peering=$(echo $peering+$number|bc)
    fi

    if [ "$(echo $data | grep repair | wc -l)" == 1 ]
    then
	  repair=$(echo $repair+$number|bc)
    fi

    if [ "$(echo $data | grep recovering | wc -l)" == 1 ]
    then
	  recovering=$(echo $recovering+$number|bc)
    fi

    if [ "$(echo $data | grep backfill | wc -l)" == 1 ]
    then
	  backfill=$(echo $backfill+$number|bc)
    fi

    if [ "$(echo $data | grep "wait-backfill" | wc -l)" == 1 ]
    then
	  waitBackfill=$(echo $waitBackfill+$number|bc)
    fi

    if [ "$(echo $data | grep incomplete | wc -l)" == 1 ]
    then
	  incomplete=$(echo $incomplete+$number|bc)
    fi

    if [ "$(echo $data | grep stale | wc -l)" == 1 ]
    then
	  stale=$(echo $stale+$number|bc)
    fi

    if [ "$(echo $data | grep remapped | wc -l)" == 1 ]
    then
	  remapped=$(echo $remapped+$number|bc)
    fi
done

ceph_osd_count=$($ceph_bin osd dump |grep "^osd"| wc -l)

function ceph_osd_up_percent()
{
  OSD_DOWN=$($ceph_bin osd dump |grep "^osd"| awk '{print $1 " " $2 " " $3}'|grep up|wc -l)
  COUNT=$(echo "scale=2; $OSD_DOWN*100/$ceph_osd_count" |bc)
  if [[ "$COUNT" != "" ]]
  then
    echo $COUNT
  else
    echo "0"
  fi
}

function ceph_osd_in_percent()
{
  OSD_DOWN=$($ceph_bin osd dump |grep "^osd"| awk '{print $1 " " $2 " " $3}'|grep in|wc -l)
  COUNT=$(echo "scale=2; $OSD_DOWN*100/$ceph_osd_count" | bc)
  if [[ "$COUNT" != "" ]]
  then
    echo $COUNT
  else
    echo "0"
  fi
}

function ceph_mon_get_active()
{
  ACTIVE=$($ceph_bin status|sed -n '/monmap/s/.* \([0-9]*\) mons.*/\1/p')
  if [[ "$ACTIVE" != "" ]]
  then
    echo $ACTIVE
  else
    echo 0
  fi
}

# Return the value
case $1 in
  health)
    status=$($ceph_bin health | awk '{print $1}')
    case $status in
      HEALTH_OK)
        echo 1
      ;;
      HEALTH_WARN)
        echo 2
      ;;
      HEALTH_ERR)
        echo 3
      ;;
      *)
        echo -1
      ;;
    esac
  ;;
  rados_total)
    $rados_bin df | grep "total space"| awk '{print $3}'
  ;;
  rados_used)
    $rados_bin df | grep "total used"| awk '{print $3}'
  ;;
  rados_free)
    $rados_bin df | grep "total avail"| awk '{print $3}'
  ;;
  mon)
    ceph_mon_get_active
  ;;
  count)
    echo $ceph_osd_count
  ;;
  up)
    ceph_osd_up_percent
  ;;
  "in")
    ceph_osd_in_percent
  ;;
  degraded_percent)
    echo $pggdegraded
  ;;
  pgtotal)
    echo $pgtotal
  ;;
  creating)
    echo $creating
  ;;
  active)
    echo $active
  ;;
  clean)
    echo $clean
  ;;
  down)
    echo $down
  ;;
  replay)
    echo $replay
  ;;
  splitting)
    echo $splitting
  ;;
  scrubbing)
    echo $scrubbing
  ;;
  degraded)
    echo $degraded
  ;;
  inconsistent)
    echo $inconsistent
  ;;
  peering)
    echo $peering
  ;;
  repair)
    echo $repair
  ;;
  recovering)
    echo $recovering
  ;;
  backfill)
    echo $backfill
  ;;
  waitBackfill)
    echo $waitBackfill
  ;;
  incomplete)
    echo $incomplete
  ;;
  stale)
    echo $stale
  ;;
  remapped)
    echo $remapped
  ;;
  ops)
    echo $ops
  ;;
  wrbps)
    echo $wrbps
  ;;
  rdbps)
    echo $rdbps
  ;;
esac
