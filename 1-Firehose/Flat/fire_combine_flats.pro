PRO FIRE_COMBINE_FLATS, filenames, ordermask, edgmask, HDR=hdr, IMAGE=image, OUTMASK=outmask, ADD=add, GAIN=gain
  
  ;; Combine all of the input flats using djs_avsigclip.pro in IDLUTILS

  prog_name = 'fire_combine_flats.pro'
  nflat = n_elements(filenames)

  ;; Irrelevant for only 1 or 2 files
  if (nflat LE 2) then sigrej = 1.0 $ 
  else if (nflat EQ 3) then sigrej = 1.1 $
  else if (nflat EQ 4) then sigrej = 1.3 $
  else if (nflat EQ 5) then sigrej = 1.6 $
  else if (nflat EQ 6) then sigrej = 1.9 $
  else sigrej = 2.0

  ;  First, cycle through all flats 
  FOR ifile = 0L, nflat-1L DO BEGIN
     print, prog_name + ': Now processing file: '+ $
            strtrim(filenames[ifile], 2)+', # '+strtrim(ifile+1, 2)+' of ' $
            +strtrim(nflat, 2)
     ;; allocate image array
     IF ifile EQ 0 THEN BEGIN
        fire_proc, filenames[ifile], image, hdr=hdr, gain=gain
        dims = size(image, /dim)
        imgarr   = make_array(dimension = [dims, nflat], /float)
        ;; this mask has 1=good, 0=bad (for avsigclip)
        maskarr = make_array(dimension = [dims, nflat], /float)
	;; modify mask, if the appropriate input arrays are provided
	if arg_present(ordermask) AND arg_present(edgmask) then begin
	  mask = (ordermask GT 0.0) AND edgmask EQ 0
	endif else if arg_present(ordermask) then begin
	  mask = ordermask GT 0.0
	endif else if arg_present(edgmask) then begin
	  mask = edgmask EQ 0
	endif else begin
	  mask = make_array(dimension = dims, /float)
	  mask[*] = 1.0
	endelse
     ENDIF ELSE BEGIN
	fire_proc, filenames[ifile], image
     ENDELSE
     if arg_present(ordermask) AND arg_present(edgmask) then begin

     endif
     if NOT arg_present(edgmask) then begin

     endif
     maskarr[*, *, ifile] = mask
     imgarr[*, *, ifile] = image
  ENDFOR  ; end, loop through input flat files

  ; Second, combine all flat files
  IF size(imgarr, /n_dimensions) EQ 3 THEN BEGIN
     if (keyword_set(ADD)) then begin
        image = total(imgarr, 3)
     endif else begin
        image = djs_avsigclip(imgarr, 3, sigrej = sigrej $
                              , maxiter = maxiter, inmask = (maskarr EQ 0) $
                              , outmask = outmask)
     endelse
  ENDIF ELSE BEGIN
     image = imgarr
  ENDELSE

END
