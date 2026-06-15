/*      MikMod sound library
   (c) 1998, 1999 Miodrag Vallat and others - see file AUTHORS for
   complete list.

   This library is free software; you can redistribute it and/or modify
   it under the terms of the GNU Library General Public License as
   published by the Free Software Foundation; either version 2 of
   the License, or (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
   02111-1307, USA.
 */

/*==============================================================================

  $Id$

  Error handling, memory, I/O functions.

==============================================================================*/

#include "unimod_priv.h"

int _um_errno = 0;

static CHAR *_um_errmsg[MMERR_MAX + 1] =
{
/* No error */

  "No error",

/* Generic errors */

  "Could not open requested file",
  "Out of memory",
  "Dynamic linking failed",

/* Sample errors */

  "Out of memory to load sample",
  "Out of sample handles to load sample",
  "Sample format not recognized",

/* Module errors */

  "Failure loading module pattern",
  "Failure loading module track",
  "Failure loading module header",
  "Failure loading sampleinfo",
  "Module format not recognized",
  "Module sample format not recognized",
  "Synthsounds not supported in MED files",
  "Compressed sample is invalid",

/* Invalid error */

  "Invalid error code"
};

char *
ML_strerror (int code)
{
  if ((code < 0) || (code > MMERR_MAX))
    code = MMERR_MAX + 1;
  return _um_errmsg[code];
}


/* Same as malloc, but sets error variable _um_error when fails */
void *
__um_malloc (size_t size)
{
  void *d;

  if (!(d = calloc (1, size)))
    {
      _um_errno = MMERR_OUT_OF_MEMORY;
    }
  return d;
}

/* Same as calloc, but sets error variable _um_error when fails */
void *
__um_calloc (size_t nitems, size_t size)
{
  void *d;

  if (!(d = calloc (nitems, size)))
    {
      _um_errno = MMERR_OUT_OF_MEMORY;
    }
  return d;
}



/*      I/O - wrappers around liburl

   The way this module works:

   - _um_read_I_* and _um_read_M_* differ : the first is for reading data
   written by a little endian (intel) machine, and the second is for reading
   big endian (Mac, RISC, Alpha) machine data.
   - _um_read_string is for reading binary strings.  It is basically the same
   as an fread of bytes.

 */

#define COPY_BUFSIZE  1024

/*========== Read functions */

int 
_um_read_string (CHAR * buffer, int number, URL reader)
{
  return url_nread (reader, buffer, number);
}

UWORD 
_um_read_M_UWORD (URL reader)
{
  UWORD result = ((UWORD) _um_read_UBYTE (reader)) << 8;
  result |= _um_read_UBYTE (reader);
  return result;
}

UWORD 
_um_read_I_UWORD (URL reader)
{
  UWORD result = _um_read_UBYTE (reader);
  result |= ((UWORD) _um_read_UBYTE (reader)) << 8;
  return result;
}

ULONG 
_um_read_M_ULONG (URL reader)
{
  ULONG result = ((ULONG) _um_read_M_UWORD (reader)) << 16;
  result |= _um_read_M_UWORD (reader);
  return result;
}

ULONG 
_um_read_I_ULONG (URL reader)
{
  ULONG result = _um_read_I_UWORD (reader);
  result |= ((ULONG) _um_read_I_UWORD (reader)) << 16;
  return result;
}

SWORD 
_um_read_M_SWORD (URL reader)
{
  return ((SWORD) _um_read_M_UWORD (reader));
}

SWORD 
_um_read_I_SWORD (URL reader)
{
  return ((SWORD) _um_read_I_UWORD (reader));
}

SLONG 
_um_read_M_SLONG (URL reader)
{
  return ((SLONG) _um_read_M_ULONG (reader));
}

SLONG 
_um_read_I_SLONG (URL reader)
{
  return ((SLONG) _um_read_I_ULONG (reader));
}

#define DEFINE_MULTIPLE_READ_FUNCTION(type_name,type)				\
int _um_read_##type_name##S (type *buffer,int number,URL reader)		\
{										\
	while(number-->0)							\
		*(buffer++)=_um_read_##type_name(reader);			\
	return !url_eof(reader);						\
}

DEFINE_MULTIPLE_READ_FUNCTION (M_SWORD, SWORD)
DEFINE_MULTIPLE_READ_FUNCTION (M_UWORD, UWORD)
DEFINE_MULTIPLE_READ_FUNCTION (I_SWORD, SWORD)
DEFINE_MULTIPLE_READ_FUNCTION (I_UWORD, UWORD)

DEFINE_MULTIPLE_READ_FUNCTION (M_SLONG, SLONG)
DEFINE_MULTIPLE_READ_FUNCTION (M_ULONG, ULONG)
DEFINE_MULTIPLE_READ_FUNCTION (I_SLONG, SLONG)
DEFINE_MULTIPLE_READ_FUNCTION (I_ULONG, ULONG)

/* ex:set ts=4: */
