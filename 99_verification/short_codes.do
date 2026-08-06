clear all
import delimited "C:\Users\weissenberg\Desktop\AOK_Revision\data_26_ano\01_Data\04_AOK_ICD10_GM.txt", clear
keep if strlen(icd) < 3
contract icd, freq(freq)
gsort -freq
list icd freq, noobs sep(0)
exit
