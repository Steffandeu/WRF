; This file is Draw Configuration.
; Hiroaki Yoshioka(yoshioka@dpac.kyoto-u.ac.jp)
; History:
; //2018 - 1st released
;
; This script calcurate inertial stability and tangential wind for hovmueller diagram.
; WRF experimental result and track data required.
; Please rewrite only the argument of "Part - Enter Constant, Directory, NAME and so on" as necessary.
;
;=====================================================================================

load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"
load "./radialAvg.ncl"
load "./AnalysisTyphoonTools.ncl"
load "./Tools.ncl"
load "./DrawConfiguration.ncl"
begin

;********** Part - Enter Constant, Directory, NAME and so on **********

  TY_NAME = "PALI"          ; case name

  WRF_DIRC   = "/Volumes/RAID01/research/DATA/WRF/PALI-v2/"    ; WRF_DIRC = "/Volumes/Yoshi-HDD01"
  TRACK_DIRC = "/Volumes/HDD01/research/ncl/wrf/track/"
  TRACK_VER  = "v25"
  OUT_DIRC   =  "~/Dropbox/research/ncl/draw/S_olr-S_prec/"+TY_NAME+"/"

  OUTNAME_PREFIX = "WRF-alldomain-horizontal-S_olr-S_prec-v1-"

  INIT = stringtointeger(systemfunc("read ifland; echo $ifland"));(/"20160103"/)     ; initial time/date
   
  MEMBER        = (/"c00", "p01", "p02", "p03", "p04", "p05", "p06", "p07", "p08", "p09", "p10" /)
  SWITCH_MEAN   = (systemfunc("read ifland; echo $ifland")) ; ON is draw, OFF is not.

  N_SKIPTIME    = stringtointeger(systemfunc("read ifland; echo $ifland"))      ; number of skip time  

  N_GRIDS       = 51       ; number of grids
  ZLEVS         = 1000     ; meter

  TYPE = "png"  ;  TYPE = "eps"  ;  TYPE = "x11"

;********** Part - Calculate dimensions and Define directory from constant (do NOT change!!!) **********
 
  n_INIT   = dimsizes(INIT)
  n_MEMBER = dimsizes(MEMBER)
  ZLEVS!0  = "lev"
  makedir(OUT_DIRC)
  SWITCH_MEAN   = str_upper(SWITCH_MEAN)
  n_rgrids = floattointeger((N_GRIDS-1)*0.5)

;*************************************************************************************

  do nnn = 0,n_INIT-1

  dirw = WRF_DIRC + INIT(nnn) + "/???/"    ; input directory
  cccc = WRF_DIRC + INIT(nnn) + "/c00/"    ; input directory
  wrflist = systemfunc("basename " + cccc +"wrfout*")
  listnum = stringtointeger(systemfunc("ls -l " + cccc +"wrfout* | wc -l"))

    do mmm = 0, n_MEMBER-1,1

    trackdata = TRACK_DIRC+"/PALI_"+INIT(nnn)+"_"+MEMBER(mmm)+"-track_v25.csv"
    print("Track data is "+trackdata)

;---Read in file as array of strings so we can parse each line
    lines  = asciiread(trackdata,-1,"string")
    nlines = dimsizes(lines)   ; First line is not a header
;---This file has quotes around everything, which we don't want.
    dq    = str_get_dq()
    lines = str_sub_str(lines,dq,"")   ; Replace quotes with empty string
;---First line is name of each field
    delim       = ","
    field_names = str_split(lines(0),delim)
    nfields     = dimsizes(field_names)
;---We're going to read the whole file as a 2D array of strings
    fields = new((/nfields,nlines/),string)
    c_ilat  = new ( (/nlines/),"integer")
    c_ilon  = new ( (/nlines/),"integer")
    c_lat  = new ( (/nlines/),"float")
    c_lon  = new ( (/nlines/),"float")

;---ReMEMBER that fields start at 1, not 0.
      do nf=0,nfields-1
      fields(nf,:) = str_get_field(lines,nf+1,delim)    
      c_ilat(:) = stringtointeger(fields(2,:))
      c_lat(:)  = stringtofloat(fields(4,:))
      c_ilon(:) = stringtointeger(fields(3,:))
      c_lon(:)  = stringtofloat(fields(5,:))
      end do

    filw = systemfunc("ls " + WRF_DIRC + INIT(nnn) + "/" + MEMBER(mmm) + "/wrfout*")  ; or WRF_*grb
    f    = addfiles (filw+".nc", "r")   ; note the "s" of addfile
    ListSetType (f, "join")

    dlat    = wrf_user_getvar(f[0],"lat",0)  ; get all times in the file
    dlon    = wrf_user_getvar(f[0],"lon",0)  ; get all times in the file
    lat     = dlat(:,0)
    lon     = dlon(0,:)
    nlat    = dimsizes(lat)
    nlon    = dimsizes(lon)
    sigma   = f[0]->ZNU(0,:)
    nz      = dimsizes(sigma)
    dx      = f[0]@DX
    dy      = f[0]@DY
    ff      = new ( (/nlat,nlon/),"float")
    ff(:,:) = f[0]->F(0,:,:)
  
    n_timestep=0

      do iii = 0,listnum-1,1
      dtimes = wrf_user_getvar(f[iii],"times",-1)  ; get all times in the file
      n_times = count_unique_values(dtimes) ; number of times in the file 
      n_timestep=n_timestep+n_times
      end do ; iii loop

    times      = new ( (/n_timestep/),"string")
    if(isdefined("olr").eq.False)then
    olr        = new ( (/n_MEMBER,n_timestep,nlat,nlon/),"float")
    prec       = new ( (/n_MEMBER,n_timestep,nlat,nlon/),"float")
    end if

    c_ttt=0

      do iii =0,listnum-1,1
    
      print("Now reading file is "+filw(iii))

      timesd = wrf_user_getvar(f[iii],"times",-1)  ; get all times in the file
      n_times = count_unique_values(timesd) ; number of times in the file 

        do it = 0,n_times-1, N_SKIPTIME
        times(c_ttt) = timesd(it)                             ; get all times in the file
        olr(mmm,c_ttt,:,:)     = wrf_user_getvar(f[iii],"OLR",it)        ;
        dammy        = wrf_user_getvar(f[iii],"RAINNC",it)    ;
        if(c_ttt.eq.0.)then
        prec(mmm,c_ttt,:,:) = dammy(:,:)
        else
        prec(mmm,c_ttt,:,:) = dammy(:,:)- dim_sum_n(prec(mmm,0:c_ttt-N_SKIPTIME,:,:),0)
        end if
        delete(dammy)

        print("Now drawing time is "+times(c_ttt))

;************************************************
; create plot of EACH MEMBER
;************************************************
; Set some basic resources

        if(c_ttt.lt.10)then
        ft_time = "FT00"+c_ttt
        else if (c_ttt.ge.10.and.c_ttt.lt.100)then
        ft_time   = "FT0"+c_ttt
        else if (c_ttt.ge.100)then
        ft_time   = "FT"+c_ttt
        end if 
        end if
        end if

        wks01 = gsn_open_wks(TYPE,OUT_DIRC + "/" + OUTNAME_PREFIX + TY_NAME + "-" + INIT(nnn) + "-" + MEMBER(mmm) + "-" + ft_time + "-" + times(c_ttt))

        res_title = True
        res_title@gsnLeftString       = ft_time + ", " + times(c_ttt)
        res_title@gsnRightString      = "Mem; " + MEMBER(mmm)

        res_basis = True
        res_basis@gsnDraw             = False
        res_basis@gsnFrame            = False
        res_basis@gsnMaximize         = True
        res_basis@vpWidthF            = 0.80
        res_basis@vpHeightF           = 0.80
        res_basis@NoHeaderFooter      = True            ; Switch headers and footers off
        res_basis = wrf_map_resources(f[iii],res_basis)
        res_basis@gsnAddCyclic          = False       ; regional data: not cyclic 
        res_basis@tfDoNDCOverlay        = True        ; set True for native mapping

;        res_basis@tiXAxisString       = "DX(km)" 
;        res_basis@tiXAxisFontHeightF  = 0.025                             ; default 
;        res_basis@tmXBMode            = "Explicit"
;        res_basis@tmXBValues          = ispan(0,N_GRIDS-1,5)
;        res_basis@tmXBLabels          = X_LABEL
        res_basis@tmXBLabelFontHeightF= 0.03

;        res_basis@tiYAxisString       = "DY(km)"
;        res_basis@tiYAxisFontHeightF  = 0.025                             ; default 
;        res_basis@tmYLMode            = "Explicit"
;        res_basis@tmYLValues          = ispan(0,N_GRIDS-1,5)
;        res_basis@tmYLLabels          = Y_LABEL
        res_basis@tmYLLabelFontHeightF= 0.03

        res = True
        res = res_basis
        res = res_title

        shade01_opts = True
        shade01_opts = res
        Config_olr_shade(shade01_opts)
        shade01_opts@tfDoNDCOverlay       = True                   ; necessary for correct overlay on map
        shade01_opts@lbLabelBarOn         = False
        shade01_opts@cnLineLabelsOn       = False                  ; turn off contour labels
        shade01_opts@cnInfoLabelOn        = False           ; turn off cn info label

        shade02_opts = True
        shade02_opts = res
        Config_prec_shade(shade02_opts)
        shade02_opts@tfDoNDCOverlay       = True                   ; necessary for correct overlay on map
        shade02_opts@lbLabelBarOn         = True

        shade01_data  = olr(mmm,c_ttt,:,:)
        shade02_data  = prec(mmm,c_ttt,:,:)
        plots         = gsn_csm_contour(wks01, shade01_data ,shade01_opts)
        plots_contour = gsn_csm_contour(wks01, shade02_data ,shade02_opts)
        overlay(plots,plots_contour)
        draw(plots)
        frame(wks01)

        c_ttt = c_ttt + N_SKIPTIME
  
        end do ;;;it loop
      end do ; iii loop

    delete(timesd)

    end do ; mmm loop
exit
  if(SWITCH_MEAN .eq."ON") then
  print("Now start to drawing ENSEMBLE MEAN.")  

;************************************************
; create plot of ENSEMBLE MEAN and SPREAD
;************************************************

    do it = 0,c_ttt-N_SKIPTIME, N_SKIPTIME

    print("Now drawing time is "+times(it))
; Set some basic resources

    if(it.lt.10)then
    ft_time = "FT00"+it
    else if (it.ge.10.and.it.lt.100)then
    ft_time   = "FT0"+it
    else if (it.ge.100)then
    ft_time   = "FT"+it
    end if 
    end if
    end if

    wks01 = gsn_open_wks(TYPE,OUT_DIRC + "/" + OUTNAME_PREFIX + TY_NAME + "-" + INIT(nnn) + "-mean-" + ft_time + "-" + times(it))
    wks02 = gsn_open_wks(TYPE,OUT_DIRC + "/" + OUTNAME_PREFIX + TY_NAME + "-" + INIT(nnn) + "-sprd-" + ft_time + "-" + times(it))

    res_title = True
    res_title@gsnLeftString       = ft_time + ", " + times(it)
    res_title@gsnRightString      = "Mem; Mean"
       
    res = res_basis
    res = res_title

    shade01_opts = True
    shade01_opts = res
    Config_inertial_stability_shade(shade01_opts)

    contour01_opts = True
    contour01_opts = res
    Config_vt_contour(contour01_opts)

    shade01_data   = dim_avg_n(instab_cyclind(:,it,:,:),0)
    contour01_data = dim_avg_n(dim_avg_n(vt_cyclind(:,it,:,:,:),3),0)
    plots          = gsn_csm_contour(wks01, shade01_data   ,shade01_opts)
    plots_contour  = gsn_csm_contour(wks01, contour01_data ,contour01_opts)
    overlay(plots,plots_contour)
    draw(plots)
    frame(wks01)
  
    res_title@gsnRightString      = "Mem; Sprd"
    res = res_basis
    res = res_title

    shade02_opts = True
    shade02_opts = res
    Config_inertial_stabilitySprd_shade(shade02_opts)
    shade02_data   = dim_stddev_n(instab_cyclind(:,it,:,:),0)
    plots          = gsn_csm_contour(wks02, shade02_data   ,shade02_opts)
    draw(plots)
    frame(wks02)

    end do ;;;it loop

  end if

  end do ; nnn loop

exit

end






