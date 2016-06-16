command! -bang -range ImpSort call impsort#sort(<line1>, <line2>, <bang>0)
command! -bang ImpSortAuto call impsort#auto(<bang>0)
