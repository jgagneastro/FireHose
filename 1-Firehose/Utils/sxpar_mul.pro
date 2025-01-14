Function sxpar_mul, files, key, EXT=ext
  forward_function headfits, sxpar, create_nan, is_number
  !except=0
  nf = n_elements(files)
  type = -1
  for i=0L, nf-1L do begin
    hdr = headfits(files[i],/silent,EXT=ext)
    vi = sxpar(hdr,key,COUNT=count)
    if count eq 0L then continue
    if ~keyword_set(output) then begin
      type = size(vi[0],/type)
      output = replicate(create_nan(type),nf)
    endif
    if type ne 7 and ~is_number(vi[0]) then continue
    valform = fix(vi[0],type=type)
    if type eq 7L then valform = strtrim(valform,2L)
    output[i] = valform
  endfor
  if ~keyword_set(output) then return, -1L else return, output
End