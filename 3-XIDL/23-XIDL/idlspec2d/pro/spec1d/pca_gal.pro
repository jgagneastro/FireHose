;+
; NAME:
;   pca_gal
;
; PURPOSE:
;   Wrapper on pca_solve.pro
;
; CALLING SEQUENCE:
;   pca_gal, [inputfile=inputfile], [wavemin=wavemin], [wavemax=wavemax], $
;            [binsz=binsz], [niter=niter], [savefile=savefile], [/flux]
;
; INPUTS:
;   None
;
; OPTIONAL INPUTS:
;   inputfile - File containing plate, mjd, fiber, redshift.  If not
;               specified, it will read eigeninput_gal.dat from
;               $IDLSPEC2D_DIR/templates
;   wavemin   - minimum wavelength, default 1850 A.
;   wavemax   - maximum wavelength, default 9300 A.
;   binsz     - Override the bin size of the final wavelength mapping.
;   flux      - Plot redshift-shifted spectra.
;   niter     - Number of iterations to pass to pca_solve, default 10.
;   savefile  - Save the input spectra to a named file for debugging.
;
; OUTPUTS:
;   None, but creates the files spEigenGal-MJD.fits & spEigenGal-MJD.ps
;
; DATA FILES:
;   $IDLSPEC2D_DIR/templates/eigeninput_gal.dat
;
; PROCEDURES CALLED:
;   get_juldate
;   dfpsplot
;   djs_readcol
;   readspec
;   skymask()
;   wavevector()
;   pca_solve()
;   djs_median()
;   djs_plot
;   djs_oplot
;   djs_xyouts
;   sxaddpar
;   mwrfits
;   dfpsclose
;
; REVISION HISTORY:
;   Written a long time ago.
;   Updated for BOSS inputs by B. A. Weaver, NYU
;
; VERSION:
;   $Id: pca_gal.pro 124695 2011-05-26 18:56:10Z weaver $
;
;------------------------------------------------------------------------------
PRO pca_gal, inputfile=inputfile, wavemin=wavemin, wavemax=wavemax, $
    binsz=binsz, flux=flux, niter=niter, savefile=savefile
    ;
    ; Define initial parameters
    ;
    IF ~KEYWORD_SET(inputfile) THEN BEGIN
        inputfile = FILEPATH('eigeninput_gal.dat', $
            ROOT_DIR=GETENV('IDLSPEC2D_DIR'), SUBDIRECTORY='templates')
    ENDIF
    IF ~KEYWORD_SET(wavemin) THEN wavemin = 1850. ; Good to z=1
    IF ~KEYWORD_SET(wavemax) THEN wavemax = 10000.
    snmax = 100
    IF ~KEYWORD_SET(niter) THEN niter = 10
    nkeep = 4
    minuse = 10
    ;
    ; Name the output files
    ;
    get_juldate, jd
    mjdstr = STRING(LONG(jd-2400000.5), FORMAT='(I5)')
    outfile = 'spEigenGal-' + mjdstr + '.fits'
    plotfile = 'spEigenGal-' + mjdstr + '.ps'
    dfpsplot, plotfile, /color, /landscape
    colorvec = ['default', 'red', 'green', 'blue', 'magenta', 'cyan']
    ;
    ; Read the input spectra
    ;
    djs_readcol, inputfile, plate, mjd, fiber, zfit, format='(L,L,L,D)'
    readspec, plate, fiber, mjd=mjd, flux=objflux, invvar=objivar, $
        andmask=andmask, ormask=ormask, plugmap=plugmap, loglam=objloglam
    ;
    ; Insist that all of the requested spectra exist
    ;
    imissing = WHERE(plugmap.fiberid EQ 0, nmissing)
    IF (nmissing GT 0) THEN BEGIN
        FOR i=0, nmissing-1 DO $
            PRINT, 'Missing plate=', plate[imissing[i]], $
                ' mjd=', mjd[imissing[i]], $
                ' fiber=', fiber[imissing[i]]
        MESSAGE, STRING(nmissing) + ' missing object(s)'
    ENDIF
    ;
    ; Do not fit where the spectrum may be dominated by sky-sub residuals.
    ;
    objivar = skymask(objivar, andmask, ormask)
    andmask = 0 ; Free memory
    ormask = 0 ; Free memory
    nobj = (SIZE(objflux, /dimens))[1]
    IF (KEYWORD_SET(snmax)) THEN BEGIN
        ifix = WHERE(objflux^2 * objivar GT snmax^2)
        IF (ifix[0] NE -1) THEN objivar[ifix] = (snmax/objflux[ifix])^2
    ENDIF
    ;
    ; Set the new wavelength mapping here...
    ; If the binsz keyword is not set, then bin size is determined from the
    ; first spectrum returned by readspec. This is fine in the case where
    ; all the spectra have the same bin size (though their starting
    ; wavelengths may differ).  However, this may not be a safe
    ; assumption in the future.
    ;
    IF ~KEYWORD_SET(binsz) THEN binsz = objloglam[1,0] - objloglam[0,0]
    newloglam = wavevector(ALOG10(wavemin), ALOG10(wavemax), binsz=binsz)
    ;
    ; Do PCA solution
    ;
    pcaflux = pca_solve(objflux, objivar, objloglam, zfit, $
        wavemin=wavemin, wavemax=wavemax, $
        niter=niter, nkeep=nkeep, newloglam=newloglam, eigenval=eigenval, $
        acoeff=acoeff, usemask=usemask, newflux=newflux, newivar=newivar)
    pcaflux = FLOAT(pcaflux)
    ;
    ; Fill in bad data with a running median of good data
    ;
    qgood = usemask GE minuse
    igood = WHERE(qgood, ngood)
    ibad = WHERE(qgood EQ 0, nbad)
    medflux = 0 * pcaflux
    IF (nbad GT 0) THEN BEGIN
        FOR i=0, nkeep-1 DO BEGIN
            medflux[igood,i] = $
                djs_median(pcaflux[igood,i], width=51, boundary='nearest')
            medflux[*,i] = djs_maskinterp(medflux[*,i], qgood EQ 0, /const)
        ENDFOR
        pcaflux[ibad,*] = medflux[ibad,*]
    ENDIF
    ;
    ; Dump input fluxes to a file for debugging purposes.
    ;
    IF KEYWORD_SET(savefile) THEN $
        SAVE, newloglam, newflux, newivar, FILENAME=savefile
    ;
    ; Make plots
    ;
    nspectra = (SIZE(newflux,/DIMENSIONS))[1]
    IF KEYWORD_SET(flux) THEN BEGIN
        nfluxes = 30L
        separation = 5.0
        nplots = nspectra/nfluxes
        IF nspectra MOD nfluxes GT 0 THEN nplots = nplots + 1L
        FOR k = 0L, nplots-1L DO BEGIN
            istart = k*nfluxes
            iend = ((istart + nfluxes) < nspectra) - 1L
            djs_plot, 10^newloglam, newflux[*,istart], $
                xrange=minmax(10^newloglam), $
                yrange=[MIN(newflux[*,istart]),MAX(newflux[*,iend])+separation*(nfluxes-1)], /xstyle, $
                color=colorvec[0], $
                xtitle='Wavelength [\AA]', $
                ytitle='Flux [10^{-17} erg cm^{-2} s^{-1} \AA^{-1}] + Constant', $
                title=STRING(istart+1L,iend+1L,FORMAT='("Galaxies: Input Spectra ",I4,"-",I4)') ;, /xlog
            FOR i=istart+1L, iend DO $
                djs_oplot, 10^newloglam, newflux[*,i]+separation*(i MOD nfluxes), $
                    color=colorvec[i MOD N_ELEMENTS(colorvec)]
        ENDFOR
    ENDIF
    djs_plot, 10^newloglam, TOTAL(newivar EQ 0,2)/nspectra, $
        color=colorvec[0], xtitle='Wavelength [\AA]', $
        ytitle='Fraction of spectra with missing data', $
        title='Missing Data'
    djs_plot, 10^newloglam, pcaflux[*,0], $
        xrange=minmax(10^newloglam), yrange=minmax(pcaflux), /xstyle, $
        color=colorvec[0], $
        xtitle='Wavelength [\AA]', ytitle='Flux [arbitrary units]', $
        title='Galaxies: Eigenspectra' ;, /xlog
    FOR i=1, nkeep-1 DO $
        djs_oplot, 10^newloglam, pcaflux[*,i], $
            color=colorvec[i MOD N_ELEMENTS(colorvec)]
    aratio10 = acoeff[1,*] / acoeff[0,*]
    aratio20 = acoeff[2,*] / acoeff[0,*]
    aratio30 = acoeff[3,*] / acoeff[0,*]
    djs_plot, aratio10, aratio20, /nodata, $
        xtitle='Eigenvalue Ratio (a_1/a_0)', $
        ytitle='Eigenvalue Ratio (a_2/a_0)', $
        title='Galaxies: Eigenvalue Ratios'
    FOR j=0, N_ELEMENTS(aratio10)-1 DO $
        djs_xyouts, aratio10[j], aratio20[j], align=0.5, $
            STRING(plate[j], fiber[j], FORMAT='(I4.4,"-",I4.4)'), $
            color=colorvec[j MOD N_ELEMENTS(colorvec)],charsize=0.5
    djs_plot, aratio20, aratio30, /nodata, $
        xtitle='Eigenvalue Ratio (a_2/a_0)', $
        ytitle='Eigenvalue Ratio (a_3/a_0)', $
        title='Galaxies: Eigenvalue Ratios'
    FOR j=0, N_ELEMENTS(aratio20)-1 DO $
        djs_xyouts, aratio20[j], aratio30[j], align=0.5, $
            STRING(plate[j], fiber[j], FORMAT='(I4.4,"-",I4.4)'), $
            color=colorvec[j MOD N_ELEMENTS(colorvec)],charsize=0.5
    ;
    ; Write output file
    ;
    sxaddpar, hdr, 'OBJECT', 'GALAXY'
    sxaddpar, hdr, 'COEFF0', newloglam[0]
    sxaddpar, hdr, 'COEFF1', binsz
    sxaddpar, hdr, 'IDLUTILS', idlutils_version(), 'Version of idlutils'
    sxaddpar, hdr, 'SPEC2D', idlspec2d_version(), 'Version of idlspec2d'
    sxaddpar, hdr, 'RUN2D', GETENV('RUN2D'), 'Version of 2d reduction'
    sxaddpar, hdr, 'RUN1D', GETENV('RUN1D'), 'Version of 1d reduction'
    FOR i=0, N_ELEMENTS(eigenval)-1 DO $
        sxaddpar, hdr, 'EIGEN'+STRTRIM(STRING(i),1), eigenval[i]
    mwrfits, pcaflux, outfile, hdr, /create
    ;
    ; Create a table of inputs
    ;
    sxaddpar, hdr2, 'FILENAME', inputfile
    inputs0 = {inputs, plate:0L, mjd:0L, fiber:0L, redshift:0.0D}
    inputs = REPLICATE(inputs0,N_ELEMENTS(plate))
    inputs.plate = plate
    inputs.mjd = mjd
    inputs.fiber = fiber
    inputs.redshift = zfit
    mwrfits, inputs, outfile, hdr2
    dfpsclose
    RETURN
END
;------------------------------------------------------------------------------
