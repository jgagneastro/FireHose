;+
; NAME:
;   spbiasave
;
; PURPOSE:
;   Average together a set (or all!) 2D pixel biases.
;
; CALLING SEQUENCE:
;   spbiasave, [ mjd=, mjstart=, mjend=, mjout=, indir=, outdir=, docam= ]
;
; INPUTS:
;
; OPTIONAL INPUTS:
;   mjd        - Valid MJD's for input pixel biases.
;   mjstart    - Valid starting MJD for input pixel biases.
;   mjend      - Valid ending MJD for input pixel biases.
;   mjout      - MJD for name of output average pixel bias; default to 0,
;                resulting in file names like 'pixbiasave-00000-b1.fits'.
;   indir      - Input directory; default to current directory.
;   outdir     - Output directory; default to same as INDIR.
;   docam      - Camera names; default to all cameras: ['b1', 'b2', 'r1', 'r2']
;
; OUTPUTS:
;
; OPTIONAL OUTPUTS:
;
; COMMENTS:
;   Some sigma-clipping is done before combining each pixel, clipping
;   at 2-sigma if more than 7 frames, and a lower sigma for fewer frames.
;
;   The output file has two HDU's, the first being the average bias,
;   the second being the standard deviation at each pixel.
;     --> Comment this out for the time being!!???
;
; EXAMPLES:
;
; BUGS:
;
; PROCEDURES CALLED:
;   djs_filepath()
;   djs_iterstat
;   fileandpath()
;   headfits()
;   mrdfits()
;   splog
;   sxaddpar
;   sxpar()
;   writefits
;
; REVISION HISTORY:
;   26-Feb-2002  Written by D. Schlegel, Princeton
;-
;------------------------------------------------------------------------------
pro spbiasave, mjd=mjd, mjstart=mjstart, mjend=mjend, mjout=mjout, $
 indir=indir, outdir=outdir, docam=docam

   if (NOT keyword_set(indir)) then indir = ''
   if (NOT keyword_set(outdir)) then outdir = indir
   if (NOT keyword_set(mjout)) then mjout = 0L

   if (keyword_set(docam)) then camnames = docam $
    else camnames = ['b1', 'b2', 'r1', 'r2']
   ncam = N_elements(camnames)

   for icam=0, ncam-1 do begin

      ; Find all input pixel biases for this camera that match the
      ; specified input MJD's.
      files = findfile(djs_filepath('pixbias-*-'+camnames[icam]+'.fits', $
       root_dir=indir), count=nfile)
      if (nfile GT 0) then begin
         thismjd = long(strmid(fileandpath(files),8,5))
         qkeep = bytarr(nfile) + 1
         if (keyword_set(mjstart)) then $
          qkeep = qkeep AND (thismjd GE mjstart)
         if (keyword_set(mjend)) then $
          qkeep = qkeep AND (thismjd LE mjend)
         if (keyword_set(mjd)) then $
          for ifile=0, nfile-1 do $
           qkeep[ifile] = qkeep[ifile] $
            AND (total(thismjd[ifile] EQ long(mjd)) NE 0)
         ikeep = where(qkeep, nfile)
         if (nfile GT 0) then files = files[ikeep]
      endif

      splog, 'Found ' + string(nfile) + ' files for camera ' + camnames[icam]

      if (nfile GT 0) then begin
         ;----------
         ; Read all the images into a single array

         hdr = headfits(files[0])
         naxis1 = sxpar(hdr,'NAXIS1')
         naxis2 = sxpar(hdr,'NAXIS2')
         npix = naxis1 * naxis2
         pixarr = fltarr(naxis1, naxis2, nfile)
         for ifile=0, nfile-1 do $
          pixarr[*,*,ifile] = mrdfits(files[ifile])

         ;----------
         ; Generate a map of the sigma at each pixel (doing some rejection).
         ; This is a horrible loop over each pixel, but shouldn't take more
         ; than a few minutes.

         if (nfile LE 2) then sigrej = 1.0 $ ; Irrelevant for only 1 or 2 biases
          else if (nfile EQ 3) then sigrej = 1.1 $
          else if (nfile EQ 4) then sigrej = 1.3 $
          else if (nfile EQ 5) then sigrej = 1.6 $
          else if (nfile EQ 6) then sigrej = 1.9 $
          else sigrej = 2.0
         maxiter = 2

         aveimg = fltarr(naxis1, naxis2)
         sigimg = fltarr(naxis1, naxis2)
         for ipix=0L, npix-1 do begin
            vals = pixarr[lindgen(nfile)*npix+ipix]
            djs_iterstat, vals, $
             sigrej=sigrej, maxiter=maxiter, sigma=sigma1, mean=mean1
            aveimg[ipix] = mean1
            sigimg[ipix] = sigma1
         endfor

         ;----------
         ; Reject pixels in the average bias where the dispersion between
         ; the input biases was large

;         maskimg = sigimg LT 0.05
;         junk = where(maskimg EQ 0, nbad)
;         splog, 'Reject ', nbad, ' pixels'
;
;         aveimg = aveimg * maskimg

pixarr = 0 ; Clear memory

         ;----------
         ; Append comments to the header

         for ifile=0, nfile-1 do $
          sxaddpar, hdr, 'COMMENT', 'Include file ' + fileandpath(files[ifile])

         ;----------
         ; Write the output file

         outfile = djs_filepath( string(mjout, camnames[icam], $
          format='("pixbiasave-",i5.5,"-",a2,".fits")'), root_dir=outdir)

         splog, 'Writing file ' + outfile
         writefits, outfile, aveimg, hdr
;         mwrfits, sigimg, outfile

      endif

   endfor

   return
end
;------------------------------------------------------------------------------
