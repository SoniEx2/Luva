LIOLIBC= int SEXIO_IOFBF = _IOFBF; \
int SEXIO_IOLBF = _IOLBF; \
int SEXIO_IONBF = _IONBF; \
int SEXIO_SEEK_SET = SEEK_SET; \
int SEXIO_SEEK_CUR = SEEK_CUR; \
int SEXIO_SEEK_END = SEEK_END;

# $(CPP) is the C prepropcessor, NOT the C++ compiler!
liolib.lua:
	echo '#include <stdio.h>' > liolib.c; echo '$(LIOLIBC)' >> liolib.c; cc -E liolib.c | lua -e 'v1,v2,v3,v4,v5,v6 = io.read"*a":match("int SEXIO_IOFBF = (.*);%s*int SEXIO_IOLBF = (.*);%s*int SEXIO_IONBF = (.*);%s*int SEXIO_SEEK_SET = (.*);%s*int SEXIO_SEEK_CUR = (.*);%s*int SEXIO_SEEK_END = (.*);")io.write(string.format("local _IOFBF,_IOLBF,_IONBF,SEEK_SET,SEEK_CUR,SEEK_END=%s,%s,%s,%s,%s,%s\n",v1,v2,v3,v4,v5,v6),io.open"liolib_.lua":read"*a")' > liolib.lua; rm liolib.c