#################################################################################
#
#  @file : mem-resource-groups.sh
#  @author : hsadashiv@vmware.com
#
#  This script is used to validate and get the memory related issues from the
#  all resource groups
#
#################################################################################

# Global
vsish=vsish
rPeakStr='peak value for requested min'
ePeakStr='peak value for effective min'

# Take care of VSI cache file, else directly run on live VSI
if [ $1 ]
then
   opts="-c $1"
else
   opts=""
fi

groups=`$vsish $opts -e ls /sched/groups/` 2> /dev/null

################################################################################
#
# MemCheck
#
# Description : Recursive function to parse the scheduler groups, this prints
#               the scheduler group tree having memory issues
#
# Arguments   : Group ID and Caller Index
#
# Return      : Nothing
#
################################################################################
MemCheck()
{
   local i=0
   local group=$1
   local call=$2
   local fromMain=$3

   groupName=`$vsish $opts -e get /sched/groups/"$group"groupName` 2> /dev/null
   memStats=`$vsish $opts -e get /sched/groups/"$group"stats/memoryStats` 2> /dev/null
   if [ $? -ne 0 ]
   then
      return
   fi

   rMinPeak=`echo "$memStats" | grep "$rPeakStr"`
   eMinPeak=`echo "$memStats" | grep "$ePeakStr"`

   rMin=`echo $rMinPeak | cut -d ':' -f 2 | cut -d ' ' -f 1`
   eMin=`echo $eMinPeak | cut -d ':' -f 2 | cut -d ' ' -f 1`

   if [ $rMin -gt $eMin ]
   then
      gFlag=`$vsish $opts -e get /sched/groups/"$group"groupFlags` 2> /dev/null
      isLeaf=`echo $gFlag | grep leaf | wc -w`
      if [ $isLeaf -ne 0 ] && [ $fromMain -eq 1 ]
      then
         return
      fi

      while [ $i -lt $call ]
      do
         echo -n "->"
         i=`expr $i + 1`
      done
      echo "Group: $groupName Requested:$rMin KB Allocatable:$eMin KB"

      local subGrps=`$vsish $opts -e ls /sched/groups/"$group"members/groups/` 2>/dev/null
      local count=`echo $subGrps | wc -w`
      if [ $count -ne 0 ]
      then
         for g in $subGrps
         do
            local g=$g"/"
            MemCheck $g `expr $call + 1` 0
         done
         echo ""
      fi
   fi
}


for g in $groups
do
   MemCheck $g 0 1
done
