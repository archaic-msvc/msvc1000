/***
*tmpfile.c - create unique file name or file
*
*       Copyright (c) Microsoft Corporation. All rights reserved.
*
*Purpose:
*       defines tmpnam() and tmpfile().
*
*******************************************************************************/

#include <cruntime.h>
#include <errno.h>
#include <process.h>
#include <fcntl.h>
#include <io.h>
#include <mtdll.h>
#include <share.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <file2.h>
#include <internal.h>
#include <tchar.h>
#include <dbgint.h>

/*
 * Buffers used by tmpnam() and tmpfile() to build filenames.
 * (Taken from stdio.h)
 * L_tmpnam(_s) = length of string _P_tmpdir
 *            + 1 if _P_tmpdir does not end in "/" or "\", else 0
 *            + 12 (for the filename string)
 *            + 1 (for the null terminator)
 * L_tmpnam_s = length of string _P_tmpdir
 *            + 1 if _P_tmpdir does not end in "/" or "\", else 0
 *            + 16 (for the filename string)
 *            + 1 (for the null terminator)
 *
 *
 *  #define L_tmpnam   (sizeof(_P_tmpdir) + 12)
 *  #define L_tmpnam_s (sizeof(_P_tmpdir) + 16)
 *
 *
 *  The 12/16 is calculated as follows
 *  The tmpname(_s) strings look like "Prefix1stPart.2ndPart"
 *  Prefix is "s" - 1 character long.
 *  1st Part is generated by ProcessID converted to string by _ultot
 *      Even for max process id == UINT_MAX, the resultant string is "3vvvvvv"
 *      i.e. 7 characters long
 *  1 character for the "."
 *  This gives a subtotal of 1 + 7 + 1 = 9 for the "Prefix1stPart."
 *
 *  The 2ndPart is generated by passing a number to _ultot.
 *  In tmpnam, the max number passed is SHRT_MAX, generating the string "vvv".
 *  i.e. 3 characters long.
 *  In tmpnam_s, the max number passed is INT_MAX, generating "1vvvvvv"
 *  i.e. 7 characters long.
 *
 *  L_tmpnam   = sizeof(_P_tmpdir + 9 + 3)
 *  L_tmpnam_s = sizeof(_P_tmpdir + 9 + 7)
 *
 */

static _TSCHAR tmpnam_buf[L_tmpnam] = { 0 };      /* used by tmpnam()  */
static _TSCHAR tmpfile_buf[L_tmpnam_s] = { 0 };      /* used by tmpfile() */
static _TSCHAR tmpnam_s_buf[L_tmpnam_s] = { 0 };      /* used by tmpnam_s() */

#define _TMPNAM_BUFFER 0
#define _TMPFILE_BUFFER 1
#define _TMPNAM_S_BUFFER 2

/*
 * Initializing function for tmpnam_buf and tmpfile_buf.
 */
#ifdef _UNICODE
static void __cdecl winit_namebuf(int);
#else  /* _UNICODE */
static void __cdecl init_namebuf(int);
#endif  /* _UNICODE */

/*
 * Generator function that produces temporary filenames
 */
#ifdef _UNICODE
static int __cdecl wgenfname(wchar_t *, size_t, unsigned long);
#else  /* _UNICODE */
static int __cdecl genfname(char *, size_t, unsigned long);
#endif  /* _UNICODE */


errno_t _ttmpnam_helper (
        _TSCHAR *s, size_t sz, int buffer_no, unsigned long tmp_max, _TSCHAR **ret
        )

{
        _TSCHAR *pfnam = NULL;
        size_t pfnameSize = 0;
        errno_t retval = 0;
        errno_t saved_errno=errno;

        _ptiddata ptd;

        if ( !_mtinitlocknum( _TMPNAM_LOCK ))
        {
                *ret = NULL;
                return errno;
        }

        _mlock(_TMPNAM_LOCK);

        __try {

        /* buffer_no is either _TMPNAM_BUFFER or _TMPNAM_S_BUFFER
        It's never _TMPFILE_BUFFER */

        if (buffer_no == _TMPNAM_BUFFER)
        {
            pfnam = tmpnam_buf;
            pfnameSize = _countof(tmpnam_buf);
        }
        else
        {
            pfnam = tmpnam_s_buf;
            pfnameSize = _countof(tmpnam_s_buf);
        }

        /*
         * Initialize tmpnam_buf, if needed. Otherwise, call genfname() to
         * generate the next filename.
         */
        if ( *pfnam == 0 ) {
#ifdef _UNICODE
                winit_namebuf(buffer_no);
#else  /* _UNICODE */
                init_namebuf(buffer_no);
#endif  /* _UNICODE */
        }
#ifdef _UNICODE
        else if ( wgenfname(pfnam, pfnameSize, tmp_max) )
#else  /* _UNICODE */
        else if ( genfname(pfnam, pfnameSize, tmp_max) )
#endif  /* _UNICODE */
                goto tmpnam_err;

        /*
         * Generate a filename that doesn't already exist.
         */
        while ( _taccess_s(pfnam, 0) == 0 )
#ifdef _UNICODE
                if ( wgenfname(pfnam, pfnameSize, tmp_max) )
#else  /* _UNICODE */
                if ( genfname(pfnam, pfnameSize, tmp_max) )
#endif  /* _UNICODE */
                        goto tmpnam_err;

        /*
         * Filename has successfully been generated.
         */
        if ( s == NULL )
        {

                /* Will never come here for tmpnam_s */
                _ASSERTE(pfnam == tmpnam_buf);
                /*
                 * Use a per-thread buffer to hold the generated file name.
                 */
                ptd = _getptd_noexit();
                if (!ptd) {
                    retval = ENOMEM;
                    goto tmpnam_err;
                }
#ifdef _UNICODE
                if ( (ptd->_wnamebuf0 != NULL) || ((ptd->_wnamebuf0 =
                      _calloc_crt(L_tmpnam, sizeof(wchar_t))) != NULL) )
                {
                        s = ptd->_wnamebuf0;
                        _ERRCHECK(wcscpy_s(s, L_tmpnam, pfnam));
                }
#else  /* _UNICODE */
                if ( (ptd->_namebuf0 != NULL) || ((ptd->_namebuf0 =
                      _malloc_crt(L_tmpnam)) != NULL) )
                {
                        s = ptd->_namebuf0;
                        _ERRCHECK(strcpy_s(s, L_tmpnam, pfnam));
                }
#endif  /* _UNICODE */
                else
                {
                        retval = ENOMEM;
                        goto tmpnam_err;
                }
        }
        else
        {
            if((buffer_no != _TMPNAM_BUFFER) && (_tcslen(pfnam) >= sz))
            {
                retval = ERANGE;

                if(sz != 0)
                    s[0] = 0;

                goto tmpnam_err;
            }

            _ERRCHECK(_tcscpy_s(s, sz, pfnam));
        }


        /*
         * All errors come here.
         */
tmpnam_err:;
        }
        __finally {
                _munlock(_TMPNAM_LOCK);
        }
        *ret = s;
        if (retval != 0)
        {
            errno = retval;
        }
        else
        {
            errno = saved_errno;
        }
        return retval ;
}


errno_t __cdecl _ttmpnam_s(_TSCHAR * s, size_t sz)
{
    _TSCHAR * ret; /* Not used by tmpnam_s */

    _VALIDATE_RETURN_ERRCODE( (s != NULL), EINVAL);

    return _ttmpnam_helper(s, sz, _TMPNAM_S_BUFFER, _TMP_MAX_S, &ret);
}

/***
*_TSCHAR *tmpnam(_TSCHAR *s) - generate temp file name
*
*Purpose:
*       Creates a file name that is unique in the directory specified by
*       _P_tmpdir in stdio.h.  Places file name in string passed by user or
*       in static mem if pass NULL.
*
*Entry:
*       _TSCHAR *s - ptr to place to put temp name
*
*Exit:
*       returns pointer to constructed file name (s or address of static mem)
*       returns NULL if fails
*
*Exceptions:
*
*******************************************************************************/

_TSCHAR * __cdecl _ttmpnam (
        _TSCHAR *s
        )
{
    _TSCHAR * ret = NULL;
    _ttmpnam_helper(s, (size_t)-1, _TMPNAM_BUFFER, TMP_MAX, &ret) ;
    return ret;
}


#ifndef _UNICODE

errno_t __cdecl _tmpfile_helper (FILE ** pFile, int shflag)
{
        FILE *stream;
        int fh;
        errno_t retval = 0;
        errno_t save_errno;

        int stream_lock_held = 0;

        _VALIDATE_RETURN_ERRCODE( (pFile != NULL), EINVAL);
        *pFile = NULL;

        if ( !_mtinitlocknum( _TMPNAM_LOCK ))
        {
                return errno;
        }

        _mlock(_TMPNAM_LOCK);

        __try {

        /*
         * Initialize tmpfile_buf, if needed. Otherwise, call genfname() to
         * generate the next filename.
         */
        if ( *tmpfile_buf == 0 ) {
                init_namebuf(_TMPFILE_BUFFER);
        }
        else if ( genfname(tmpfile_buf, _countof(tmpfile_buf), _TMP_MAX_S) )
                goto tmpfile_err;

        /*
         * Get a free stream.
         *
         * Note: In multi-thread models, the stream obtained below is locked!
         */
        if ( (stream = _getstream()) == NULL ) {
                retval = EMFILE;
                goto tmpfile_err;
        }

        stream_lock_held = 1;

                /*
         * Create a temporary file.
         *
         * Note: The loop below will only create a new file. It will NOT
         * open and truncate an existing file. Either behavior is probably
         * legal under ANSI (4.9.4.3 says tmpfile "creates" the file, but
         * also says it is opened with mode "wb+"). However, the behavior
         * implemented below is compatible with prior versions of MS-C and
         * makes error checking easier.
         */
        save_errno = errno;
        errno = 0;
        while ( (_sopen_s(&fh, tmpfile_buf,
                              _O_CREAT | _O_EXCL | _O_RDWR | _O_BINARY |
                                _O_TEMPORARY,
                              shflag,
                              _S_IREAD | _S_IWRITE
                             ) == EEXIST) )
        {
                if ( genfname(tmpfile_buf, _countof(tmpfile_buf), _TMP_MAX_S) )
                        break;
        }

        if(errno == 0)
        {
            errno = save_errno;
        }

        /*
         * Check that the loop above did indeed create a temporary
         * file.
         */
        if ( fh == -1 )
                goto tmpfile_err;

        /*
         * Initialize stream
         */
#ifdef _DEBUG
        if ( (stream->_tmpfname = _calloc_crt( (_tcslen( tmpfile_buf ) + 1), sizeof(_TSCHAR) )) == NULL )
#else  /* _DEBUG */
        if ( (stream->_tmpfname = _tcsdup( tmpfile_buf )) == NULL )
#endif  /* _DEBUG */
        {
                /* close the file, then branch to error handling */
                _close(fh);
                goto tmpfile_err;
        }
#ifdef _DEBUG
        _ERRCHECK(_tcscpy_s( stream->_tmpfname, _tcslen( tmpfile_buf ) + 1, tmpfile_buf ));
#endif  /* _DEBUG */
        stream->_cnt = 0;
        stream->_base = stream->_ptr = NULL;
        stream->_flag = _commode | _IORW;
        stream->_file = fh;

        *pFile = stream;

        /*
         * All errors branch to the label below.
         */
tmpfile_err:;
                }
        __finally {
                if ( stream_lock_held )
                        _unlock_str(stream);
                _munlock(_TMPNAM_LOCK);
        }

        if (retval != 0)
        {
            errno = retval;
        }
        return retval ;
}

/***
*FILE *tmpfile() - create a temporary file
*
*Purpose:
*       Creates a temporary file with the file mode "w+b".  The file
*       will be automatically deleted when closed or the program terminates
*       normally.
*
*Entry:
*       None.
*
*Exit:
*       Returns stream pointer to opened file.
*       Returns NULL if fails
*
*Exceptions:
*
*******************************************************************************/

FILE * __cdecl tmpfile (void)
{
    FILE * fp = NULL;
    _tmpfile_helper(&fp, _SH_DENYNO);
    return fp;
}

/***
*errno_t *tmpfile_s - create a temporary file
*
*Purpose:
*       Creates a temporary file with the file mode "w+b".  The file
*       will be automatically deleted when closed or the program terminates
*       normally. Similiar to tmpfile, except that it opens the tmpfile in
*       _SH_DENYRW share mode.
*
*Entry:
*       FILE ** pFile - in param to fill the FILE * to.
*
*Exit:
*       returns 0 on success & sets pfile
*       returns errno_t on failure.
*       On success, fills in the FILE pointer into the in param.
*
*Exceptions:
*
*******************************************************************************/

errno_t __cdecl tmpfile_s (FILE ** pFile)
{
    return _tmpfile_helper(pFile, _SH_DENYRW);
}

#endif  /* _UNICODE */

/***
*static void init_namebuf(flag) - initializes the namebuf arrays
*
*Purpose:
*       Called once each for tmpnam_buf and tmpfile_buf, to initialize
*       them.
*
*Entry:
*       int flag            - flag set to 0 if tmpnam_buf is to be initialized,
*                             set to 1 if tmpfile_buf is to be initialized.
*                             set to 2 if tmpnam_s_buf is to be initialized.
*Exit:
*
*Exceptions:
*
*******************************************************************************/

#ifdef _UNICODE
static void __cdecl winit_namebuf(
#else  /* _UNICODE */
static void __cdecl init_namebuf(
#endif  /* _UNICODE */
        int flag
        )
{
        _TSCHAR *p, *q;
        size_t size = 0;

        switch(flag)
        {
            case 0 :
                p = tmpnam_buf;
                size = _countof(tmpnam_buf);
                break;

            case 1 :
                p = tmpfile_buf;
                size = _countof(tmpfile_buf);
                break;

            case 2 :
                p = tmpnam_s_buf;
                size = _countof(tmpnam_s_buf);
                break;

        }

        /*
         * Put in the path prefix. Make sure it ends with a slash or
         * backslash character.
         */
#ifdef _UNICODE
        _ERRCHECK(wcscpy_s(p, size, _wP_tmpdir));
#else  /* _UNICODE */
        _ERRCHECK(strcpy_s(p, size, _P_tmpdir));
#endif  /* _UNICODE */
        q = p + sizeof(_P_tmpdir) - 1;      /* same as p + _tcslen(p) */

        if  ( (*(q - 1) != _T('\\')) && (*(q - 1) != _T('/')) )
                *(q++) = _T('\\');

        /*
         * Append the leading character of the filename.
         */
        if ( flag == _TMPFILE_BUFFER )
                /* for tmpfile() */
                *(q++) = _T('t');
        else
                /* for tmpnam() & _tmpnam_s */
                *(q++) = _T('s');

        /*
         * Append the process id, encoded in base 32. Note this makes
         * p back into a string again (i.e., terminated by a '\0').
         */
        _ERRCHECK(_ultot_s((unsigned long)_getpid(), q, size - (q - p), 32));
        _ERRCHECK(_tcscat_s(p, size, _T(".")));
}


/***
*static int genfname(_TSCHAR *fname) -
*
*Purpose:
*
*Entry:
*
*Exit:
*
*Exceptions:
*
*******************************************************************************/

#ifdef _UNICODE
static int __cdecl wgenfname (
#else  /* _UNICODE */
static int __cdecl genfname (
#endif  /* _UNICODE */
        _TSCHAR *fname, size_t fnameSize, unsigned long tmp_max
        )
{
        _TSCHAR *p;
        _TSCHAR pext[8];        // 7 positions for base 32 ulong + null terminator
        unsigned long extnum;

        p = _tcsrchr(fname, _T('.'));

        p++;

        _VALIDATE_RETURN_NOERRNO(p >= fname && fnameSize > (size_t)(p-fname), -1);


        if ( (extnum = _tcstoul(p, NULL, 32) + 1) >= tmp_max )
                return -1;

        _ERRCHECK(_ultot_s(extnum, pext, _countof(pext), 32));
        _ERRCHECK(_tcscpy_s(p, fnameSize - (p - fname), pext));

        return 0;
}

#if !defined (_UNICODE) && !defined (CRTDLL)

/***
*void __inc_tmpoff(void) - force external reference for _tmpoff
*
*Purpose:
*       Forces an external reference to be generate for _tmpoff, which is
*       is defined in cinittmp.obj. This has the forces cinittmp.obj to be
*       pulled in, making a call to rmtmp part of the termination.
*
*Entry:
*
*Exit:
*
*Exceptions:
*
*******************************************************************************/


extern int _tmpoff;

void __inc_tmpoff(
        void
        )
{
        _tmpoff++;
}

#endif  /* !defined (_UNICODE) && !defined (CRTDLL) */
