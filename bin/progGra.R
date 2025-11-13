### redirect to postscript:
# postscript("FILENAME.eps", onefile=FALSE, height=3, width=12, pointsize=1)
# ProgGraph()
# dev.off()

ReadData <- function(fn, sw = '---') {
  cat("Reading Keyboard data:", fn,".kd\n");
  # quote="" allows for \\ in the chars but keeps the ""
  Keys     <<- read.table(paste(fn,".kd",sep=""), header = TRUE)
#  Keys     <<- read.table(paste(fn,".kd",sep=""), quote="", header = TRUE)
  # take out ""
#  Keys$Char <<- sapply(Keys$Char, function(x) gsub("^\"", "", x))
#  Keys$Char <<- sapply(Keys$Char, function(x) gsub("\"$", "", x))

  cat("Reading Fixation data:", fn,".fd\n");
  Fixes    <<- read.table(paste(fn,".fd",sep=""), header = TRUE)
  if (file.exists(paste(fn,".fu",sep=""))){
    cat("Reading Fixation Units:", fn,".fu\n");
    FU       <<- read.table(paste(fn,".fu",sep=""), header = TRUE)
  }
  if (file.exists(paste(fn,".pu",sep=""))){
    cat("Reading Production Units:", fn,".pu\n");
    PU       <<- read.table(paste(fn,".pu",sep=""), header = TRUE)
  }
# Compatibility with cu files
  if (file.exists(paste(fn,".cu",sep=""))){
    cat("Reading Activity Units:", fn,".cu\n");
    AU       <<- read.table(paste(fn,".cu",sep=""), header = TRUE)
  }
  else if (file.exists(paste(fn,".au",sep=""))){
    cat("Reading Activity Units:", fn,".au\n");
    AU       <<- read.table(paste(fn,".au",sep=""), header = TRUE)
  }

  if(sw == '---') {
    cat("Reading Source Text:", fn,".st\n");
    Source <<- read.table(paste(fn,".st",sep=""), header = TRUE)
#    Source <<- read.table(paste(fn,".st",sep=""), quote="", header = TRUE)
  # take out ""
#Keys$Char <<- sapply(Keys$Char, function(x) gsub("^\"", "", x))
#  Keys$Char <<- sapply(Keys$Char, function(x) gsub("\"$", "", x))
#    Source <<- read.table(paste(fn,".st",sep=""), header = TRUE)
  }
  else { Source   <<- read.table(sw, header = TRUE) }
  FileName <<- fn;

#  s2 <<- as.numeric()
#  for (i in 0:length(Keys$STid)) {
#    cat("char:", Keys$STid[i], "  ", Keys$Time[i], "\n");
#    s2[i] <<- as.integer(unlist(strsplit(as.character(Keys$STid[i]), "[+]"))[[1]]);
#  }

#  Keys$STid <<- s2;
}


########################################
# X1 and X2: segment to be plotted 
# Y1 and Y2: adjust range of the segment 
# keystrokes are always shown
# fixations can be suppressed with fix=0
# suppress segment boundary line with seg=0
# CK=1 don't plot unmapped keystrokes
# show production-, fixation-, activity units with pu=1 fu=1, au=1
# label: show labels 
# seg: show segment boundaries


ProgGraph <- function(X1=0, X2=0, Y1=0, Y2=0, fix=1, pu=0, fu=0, au=0, tu=0, seg=1, CK=0, label=1) {

  if(length(Fixes$Time) == 0) {
    cat("Fixation table empty: cannot plot fixations\n");
    fix=0;
  }
  if(fu == 1 && length(FU$Id) == 0) {
    cat("Fixation units table empty: cannot plot fixation units\n");
    fu=0;
  }
  if(pu == 1 && length(PU$Id) == 0) {
    cat("Production units table empty: cannot plot production units\n");
    pu=0;
  }

  if(length(Keys$Time) == 0) {
    cat("No Key data: cannot plot Graph \n");
    return;
  }

## CK: only classified keystrokes
  if(X1 > X2) { cat( "X1 must be smaller than or equal to X2\n"); return; }
  if(Y1 > Y2) { cat( "Y1 must be smaller than or equal to Y2\n"); return; }
  if(Y1 == Y2) {
    if(X1 == X2){Y1=0;Y2 = length(Source[,2]);}
    else {
      for (i in 1:length(Keys$Time)) {
        if(Keys$Time[i] < X1 || Keys$Time[i] > X2 ) {next;}
        if(Keys$STid[i] < 0 && CK == 1) {next;}
        if(Y2 == Y1){ Y1 <- Keys$STid[i];Y2 <- Keys$STid[i]+1; next;}
        if(Y1 > Keys$STid[i]) {Y1 <- Keys$STid[i];}
        if(Y2 < Keys$STid[i]) {Y2 <- Keys$STid[i];}
  } } }
  if(X1 == X2){
    for (i in 1:length(Keys$Time)) {
#cat( "KEY", i, length(Keys$Time), "X1:", X1, "X2:", X2, "\n");
      if(Keys$STid[i] > 0 && (Keys$STid[i] < Y1 || Keys$STid[i] > Y2 )) {next;}
      if(X2 == X1){ X1 <- Keys$Time[i];X2 <- Keys$Time[i]+1; next;}
      if(X1 > Keys$Time[i]) {X1 <- Keys$Time[i];}
      if(X2 < Keys$Time[i]) {X2 <- Keys$Time[i];}
#if(i > 10 ) {break;}
    }
    if(fix == 1) {
      for (i in 1:length(Fixes$Time)) {
        if(Fixes$STid[i] > Y2 || Fixes$STid[i] < Y1) {next;}
        if(X1 > Fixes$Time[i]) {X1 <- Fixes$Time[i];}
        if(X2 < Fixes$Time[i]) {X2 <- Fixes$Time[i]; }
    } }
  }
 

# 1:black, 2:red, 3:blue, 4:green
# color insertions/deletions
  kt  <-  c(); 
  for (i in 1:length(Keys$Type)) {
# 1:black, 2:red, 3:blue, 4:green

    if(Keys$Type[i] == "Mins") {kt[i] <- "black";} else
    if(Keys$Type[i] == "ins") {kt[i] <- "black";} else
    if(Keys$Type[i] == "Ains") {kt[i] <- "grey";} else
    if(Keys$Type[i] == "Sins") {kt[i] <- "grey" ;} else
    if(Keys$Type[i] == "Mdel") {kt[i] <- "red";} else
    if(Keys$Type[i] == "del") {kt[i] <- "red";} else
    if(Keys$Type[i] == "Adel") {kt[i] <- "pink" ;} else
    if(Keys$Type[i] == "Sdel") {kt[i] <- "orange" ;} else
    {kt[i] <- "yellow";}
  }


#cat( "XXX", Y2-Y1, pu, fu, fix);
  par(mai=c(0.8,2.0,0.2,1.5))

#  xlab  <-  paste("Translation Progression Graph " , FileName , "Translation time ", X1, " to ", X2, " (in ms)");
#  ylab  <-  paste("Source Text", Y1, "to" , Y2);
  xlab  <-  "";
  ylab  <-  "";
  yaxt  <-  "n";
  if(label == 1) {yaxt <- 'true';}
# Mit Zahlen an der  Y-achse
  plot(Keys$Time,Keys$STid,mgp=c(7,0.6,0),yaxt=yaxt,lab=c(25,10,2),
       type="n",xlab=xlab,ylab=ylab,xlim=c(X1,X2),ylim=c(Y1,Y2))
  axis(2,at=Source$Id,labels=Source$SToken,las=1,mgp=c(10,2.0,0),tck=0.01)
  axis(4,at=Source$Id,labels=Source$TGroup,las=1,mgp=c(10,1.0,0),tck=0.01)

  text(Keys$Time,Keys$STid,as.character(Keys$Char),cex=1.0,col=kt);
 
  ## Polygon Processing Units
  if(fix == 1) { 
    Fe  <-  c(); 
    Fc  <-  c(); 
    Fs  <-  c();
    Fz  <-  c();
    Ft  <-  c();

  # fixation size changes according to X/Y size of window
    scf = log2(sqrt((X2-X1)*(Y2-Y1))) + 10;
    for (i in 1:length(Fixes$Time)) { 
      if(Fixes$Time[i] > X2) {break;}
      if(Fixes$Time[i]+Fixes$Dur[i] < X1) {next}

      color <- "blue";
      if(Fixes$Win[i] == "1") { 
         Fc =append(Fc, "blue"); 
         Ft =append(Ft, 21); 
      }
      else { 
         Fc =append(Fc, "green"); 
         Ft =append(Ft, 23); 
         color <- "green";
      }

      fixSize <- log10(Fixes$Dur[i] / scf); 
      if(fixSize < 0.3) { 
        Fz =append(Fz, 0.3);
      }
      else {
        Fz =append(Fz, fixSize);
      }

      Fs =append(Fs, Fixes$Time[i] +(Fixes$Dur[i]/ 2));
      Fe =append(Fe, Fixes$STid[i]);
    
      min <- Fixes$STid[i]-0.5;
      max <- Fixes$STid[i]+0.5;
    
      rect(Fixes$Time[i], min, Fixes$Time[i]+Fixes$Dur[i], max, border=color, col=NA);
    }
    points(Fs, Fe, type="b", pch=Ft, bg=Fc, col="grey", cex=Fz); 
  }
  
## Polygon Processing Units
  if(pu == 1) { 
    PUx  <- c(); 
    PUy  <- c(); 
    PUlx <- c();
    PUly <- c();
    PUl  <- c();
    PUa  <- c();
    PUt = 0;
#    min <- Y1+((Y2-Y1)/100);
    min <- Y1+((Y2 -Y1)/5);
    max <- Y2-((Y2 -Y1)/1.5);
    
    for (i in 1:length(PU$Time)) { 
      if(PU$Time[i] > X2) {break;}
      if(PU$Time[i]+PU$Dur[i] < X1) {next}

  ## update X2 for last FU overlapping PU
      if(PU$Time[i]+PU$Dur[i] > X2) {X2 = PU$Time[i]+PU$Dur[i];}
      PUx=append(PUx,PU$Time[i]); 
      PUx=append(PUx,PU$Time[i]); 
      PUx=append(PUx,PU$Time[i]+PU$Dur[i]); 
      PUx=append(PUx,PU$Time[i]+PU$Dur[i])
      PUx=append(PUx,NA);

      PUy = append(PUy, min);
      PUy = append(PUy, max);
      PUy = append(PUy, max);
      PUy = append(PUy, min);
      PUy = append(PUy, NA);
      PUt = 1;
      if(label == 1) {
        PUlx = append(PUlx, PU$Time[i]);
        PUly = append(PUly, max);
#        PUl  = append(PUl, paste("Pause: ", as.character(PU$Pause[i]), "ms", "\n"));
        PUl  = append(PUl, paste("Dur:", as.character(PU$Dur[i]), "\n"));
      }
##############
    }
    if(PUt == 1) {
      polygon(PUx,PUy,density=10,angle=0,lty=1,col="black",lwd=0.4); 
      if(label == 1) {text(PUlx,PUly,PUl,srt=40,cex=1, adj = c(0, 0.5));}
  } }

## Polygon Fixation Units
  if(fu == 1) {
    FUx <- c(); 
    FUy <- c();
    FUc <- c();
    FUlx <- c();
    FUly <- c();
    FUl <- c();
    FUa <- c();
    FUt = 0;

    min <- Y1+((Y2-Y1)/10);
    max <- Y2-((Y2-Y1)/2);

#cat( "FU pu:", pu, "  fu:", fu, "\n");
    for (i in 1:length(FU$Time)) {
      if(FU$Time[i] > X2) {break;}
      if(FU$Time[i]+FU$Dur[i] < X1) {next}

      if(FU$Win[i] == 1) { FUc = append(FUc, "blue3"); FUa = append(FUa, 45);}
      else if(FU$Win[i] == 2) { FUc = append(FUc, "green3");FUa = append(FUa, -45);}
      else if(FU$Win[i] == 8) { FUc = append(FUc, "black"); FUa = append(FUa, 0);}
      else { FUc = append(FUc, "red");FUa = append(FUa, 90);}

      FUx=append(FUx,FU$Time[i]); 
      FUx=append(FUx,FU$Time[i]); 
      FUx=append(FUx,FU$Time[i]+FU$Dur[i]); 
      FUx=append(FUx,FU$Time[i]+FU$Dur[i])
      FUx=append(FUx,NA);

      FUy = append(FUy, min);
      FUy = append(FUy, max);
      FUy = append(FUy, max);
      FUy = append(FUy, min);
      FUy = append(FUy, NA);
      FUt = 1;
	  
      FUlx = append(FUlx, FU$Time[i]);
      FUly = append(FUly, max);
      FUl  = append(FUl, paste(#"FU: ", FU$Win[i],
                              "D:", FU$Dur[i], 
#                              "\nSpan: ",FU$ScSpan[i],
#                              "\nTurn: ",FU$Turn[i],
#                              "\nnFix: ",FU$nFix[i],
#                              "\nFix: ", FU$Fix[i],
                              sep=""));
      
      FUl = append(FUl, as.character(FU$Label[i]));

    }
    if(FUt == 1) {
      polygon(FUx,FUy,density=2,angle=FUa,lty=1,col=FUc,lwd=1.8);
      if(label > 0) {text(FUlx,FUly,FUl,srt=60,cex=1, adj = c(0, 0.5), col=FUc);}
    }
    
  }
        
  
  if(tu == 1) {
    TUx <- c(); 
    TUy <- c();
    TUlx <- c();
    TUly <- c();
    TUl <- c();
    TUt = 0;
	min = Y1;
	max = Y2; #- ((Y2-Y1)/10);
	labY = min;
      
    for (i in 1:length(PU$TimeTU)) {
      if(PU$TimeTU[i] > X2) {break;}
      if(PU$TimeTU[i] < X1) {next}
      
      TUx=append(TUx,PU$TimeTU[i]); 
      TUx=append(TUx,PU$TimeTU[i]); 
      TUx=append(TUx,NA);

      TUy = append(TUy, min);
      TUy = append(TUy, max);
      TUy = append(TUy, NA);
      TUt = 1;
  
      if(label == 1) {
        TUlx = append(TUlx, PU$TimeTU[i]);
        TUly = append(TUly, labY);
        TUl  = append(TUl, paste(" ", as.character(PU$Id[i]), sep="", "\n"));
      }
    }
    if(TUt == 1) {
      polygon(TUx,TUy,density=0,angle=0,lty=3,col="red",lwd=4.0); 
      if(label == 1) {text(TUlx,TUly,TUl,srt=0,cex=1, adj=c(0, 0.5));}	  
    }
  }
##############


  if(au == 1) {
    AUx <- c(); 
    AUy <- c();
    AUlx <- c();
    AUly <- c();
    AUl <- c(); 
    AUc <- c();
    AUa <- c();
    AUt = 0;
    min <- Y1;
    max <- Y2;
    if(label == 1) {max <- Y2-((Y2 -Y1)/3);}
  
    for (i in 1:length(AU$Time)) {
      if(AU$Time[i] > X2) {break;}
      if(AU$Time[i]+AU$Dur[i] < X1) {next}

      if(AU$Type[i] == 1) { AUc = append(AUc, "blue3"); AUa = append(AUa, 0);}
      else if(AU$Type[i] == 2) { AUc = append(AUc, "green3");AUa = append(AUa, 75);}
      else if(AU$Type[i] == 3) { AUc = append(AUc, "darkcyan");AUa = append(AUa, -30);}
      else if(AU$Type[i] == 4) { AUc = append(AUc, "orange");AUa = append(AUa, 45);}
      else if(AU$Type[i] == 5) { AUc = append(AUc, "violetred");AUa = append(AUa, 45);}
      else if(AU$Type[i] == 6) { AUc = append(AUc, "darkgreen");AUa = append(AUa, -45);}
      else if(AU$Type[i] == 7) { AUc = append(AUc, "coral4");AUa = append(AUa, 30);}
      else if(AU$Type[i] == 8) { AUc = append(AUc, "black");AUa = append(AUa, 0);}
      else { AUc = append(AUc, "red");AUa = append(AUa, -75);}

      AUx=append(AUx,AU$Time[i]); 
      AUx=append(AUx,AU$Time[i]); 
      AUx=append(AUx,AU$Time[i]+AU$Dur[i]); 
      AUx=append(AUx,AU$Time[i]+AU$Dur[i]);
      AUx=append(AUx,NA);

      AUy = append(AUy, min);
      AUy = append(AUy, max);
      AUy = append(AUy, max);
      AUy = append(AUy, min);
      AUy = append(AUy, NA);
      
      AUt = 1;
    
#      if(AU$Type[i] == 1) {
#        AUlx = append(AUlx, AU$Time[i]+2100);
#        AUly = append(AUly, min+0.5);
#        AUl = append(AUl, paste(" Type: ", AU$Type[i]));
#        if(label == 2) {
#          AUl = append(AUl, paste("\nPhase: ",AU$Phase[i],
#                              "\nDur: ",AU$Dur[i], 
#                              "\nSpan: ",AU$ScSpan[i],
#                              "\nTurn: " ,AU$Turn[i],
#                              "\nnFix: ",AU$nFix[i],
#                              "\nSD: ",AU$SD[i],
#                              "\nDfix: ",AU$DFix[i],
#                              "\nLin: ",AU$Lin[i],
#                              sep=""));
#      } }
#      else{
      AUl = append(AUl, paste(" AU:", AU$Type[i], " Dur:",AU$Dur[i], sep=""));
      AUlx = append(AUlx, AU$Time[i]);
      AUly = append(AUly, max);
    }
 
    if(AUt == 1) {
      polygon(AUx,AUy,density=0,angle=AUa,lty=2,col=AUc,lwd=2.8);
      if(label > 0) {text(AUlx,AUly,AUl,srt=66,cex=1, adj = c(0, 0.5), col=AUc);}
  } }

## draw segment boundary line
  if(seg == 1) {
    lastSeg  <-  0;
    for (i in 1:length(Source$STseg)) {
      if(i > Y2) {break;}
      if(i < Y1) {next}

      if(Source$STseg[i] != lastSeg) { 
        abline(h=i-1, v=0, col = "gray30");
        if(label == 1){
          l = paste("Seg:", Source$STseg[i]);
          text(X1,i+((Y2-Y1)/40),l,srt=35);
		    }
      }
      lastSeg = Source$STseg[i];
    }
  }
}
