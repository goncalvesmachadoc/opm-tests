#!/bin/bash
# needs summary from opm, gnuplot, and pdflatex

# this is using program summay found in opm-common
SUMMARY=$1/summary

DIRS="$2"
test -z "$DIRS" && DIRS="ECL.2014.2 opm-simulation-reference/flow_legacy"
OUTPUT=$3
test -z "$OUTPUT" && OUTPUT=norne-wells
DECK=NORNE_ATW2013

test -d flow_legacy && DIRS="$DIRS flow_legacy"
test -d flow && DIRS="$DIRS flow"
test -d flow_4_proc && DIRS="$DIRS flow_4_proc"

# if empty all options will be plotted
OPTS="WBHP WOPR WGPR WWPR"

ALLWELLS=
ALLOPTS=$OPTS
for DIR in $DIRS; do
  ALLWELLS=`$SUMMARY -l $DIR/$DECK`
done

WELLS=
for W in $ALLWELLS; do
  WELL=`echo $W | grep WBHP | grep -v WBHPH`

  if [ "$ALLOPTS" == "" ]; then
    OPT=`echo $W | cut -d ":" -f 1`

    CONTAINED=`echo $OPTS | grep $OPT`
    if [ "$CONTAINED" == "" ]; then
      OPTS="$OPTS $OPT"
      echo "Found option $OPT"
    fi
  fi

  if [ "$WELL" != "" ] ; then
    WELL=`echo $WELL | cut -d ":" -f 2`
    WELLS="$WELLS $WELL"
    echo "Found well $WELL"
  fi
done

# create a file for each well for all specified wells
for DIR in $DIRS; do
  if ! test -d $DIR ; then
    echo "ERROR: directory $DIR does not exist"
    exit 1
  fi
  for WELL in $WELLS ; do
    echo "Creating file $DIR/${WELL}.gnu"
    WELLOPTS=
    for OPT in $OPTS; do
      WELLOPTS="$WELLOPTS $OPT:$WELL"
    done
    $SUMMARY $DIR/$DECK TIME $WELLOPTS > $DIR/$WELL.gnu
  done
done

WELLLISTEX=$OUTPUT-list.tex
echo "" > $WELLLISTEX

PLOTFILE=$OUTPUT.gnu

PICCOUNT=1 # 1 is days
for WELL in $WELLS ; do
  COUNT=2 # 1 is days
  for OPT in $OPTS; do
    echo "set terminal postscript color" > $PLOTFILE
    echo "set output \"well-${WELL}-${OPT}.eps\"" >> $PLOTFILE
    echo "set xlabel \"days\"" >> $PLOTFILE
    echo "set ylabel \"$OPT\"" >> $PLOTFILE
    echo "set grid" >> $PLOTFILE
    PLOTS=
    LC=1
    LW=3
    for DIR in $DIRS; do
      if [ "$PLOTS" != "" ]; then
        PLOTS="$PLOTS,"
        LC=`expr $LC + 2`
      fi
      title=`echo $DIR | tr _ -`
      PLOTS="$PLOTS \"${DIR}/$WELL.gnu\" u 1:${COUNT} title \"$title\" w l lw $LW lc $LC"
    done
    echo "plot $PLOTS" >> $PLOTFILE
    gnuplot $PLOTFILE

    echo "\\begin{figure}" >> $WELLLISTEX
    echo "\\rotatebox{270}{\\includegraphics[width=0.65\\textwidth]{well-$WELL-$OPT}}\\\\" >> $WELLLISTEX
    echo "\\caption{$OPT of well \\textbf{$WELL}.}" >> $WELLLISTEX
    echo "\\end{figure}" >> $WELLLISTEX
    if [ "`expr $PICCOUNT % 2`" == "0" ] || [ ]; then
      echo "\\clearpage" >> $WELLLISTEX
    fi
    COUNT=`expr $COUNT + 1`
    PICCOUNT=`expr $PICCOUNT + 1`
  done
done

WELLTEX=$OUTPUT.tex

TEXFILE="
\\documentclass{article}
\\usepackage{graphicx}
\\setlength{\\hoffset}{0cm}
\\setlength{\\topmargin}{0.5cm}
\\setlength{\\headsep}{0cm}
\\setlength{\\headheight}{0cm}
\\setlength{\\textheight}{23cm}
\\setlength{\\textwidth}{15.5cm}
\\setlength{\\evensidemargin}{0.48cm}
\\setlength{\\oddsidemargin}{0.0cm}
\\begin{document}
\\input{$WELLLISTEX}
\\end{document}"

echo $TEXFILE | latex --interaction=nonstopmode
echo $TEXFILE | latex --interaction=nonstopmode

dvipdf article $OUTPUT.pdf

# remove temporary files
rm -f $WELLLISTEX
rm -f $PLOTFILE
for DIR in $DIRS; do
  rm -f $DIR/*.gnu
done
rm -f $WELLTEX $OUTPUT.aux $OUTPUT.log $OUTPUT.dvi
find . -name "well-*.eps" -exec rm {} \;
