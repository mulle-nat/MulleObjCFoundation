//
//  NSData+PropertyListPrinting.m
//  MulleObjCEOUtil
//
//  Created by Nat! on 16.08.09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "NSData+PropertyListPrinting.h"

// other files in this library
#import "NSObject+PropertyListPrinting.h"

// std-c and dependencies
#include <ctype.h>


@implementation NSData ( PropertyListPrinting)

static inline unsigned char   toHex( unsigned char c)
{
   return( c >= 10 ? c + 'a' - 10 : c + '0');
}


- (NSData *) newPropertyListUTF8DataWithIndent:(unsigned int) indent
{
   size_t          i, len;
   size_t          out_len;
   unsigned char   *p;
   unsigned char   *q;
   NSMutableData   *buffer;

   len     = [self length];
   out_len = 1 + len * 2 + ((len + 3) / 4) - 1 + 1;
   buffer   = [[NSMutableData alloc] initWithLength:out_len];

   p = (unsigned char *) [self bytes];
   q = (unsigned char *) [buffer bytes];
   
   *q++ = '<';
   for( i = 0; i < len; i++)
   {
      *q++ = toHex( *p >> 4);
      *q++ = toHex( *p & 0xF);
      ++p;
      if( (i & 0x3) == 3 && i != len -1)
         *q++ = ' ';
   }
   *q = '>';
   
   return( buffer);
}


- (NSData *) propertyListUTF8DataWithIndent:(unsigned int) indent
{
   return( [[self newPropertyListUTF8DataWithIndent:indent] autorelease]);
}

 
- (void) propertyListUTF8DataToStream:(id <_MulleObjCOutputDataStream>) handle
                                  indent:(unsigned int) indent;
{
   NSData   *data;
   
   data = [self newPropertyListUTF8DataWithIndent:indent];
   [handle writeData:data];
   [data release];
}


extern int  _dude_looks_like_a_number( char *buffer, size_t len);

- (BOOL) propertyListUTF8DataNeedsQuoting
{
   size_t          len;
   mulle_utf8_t    *s;
   mulle_utf8_t    *sentinel;
   
   len = [self length];
   if( ! len || len > 128)
      return( YES);
      
   s = (unsigned char *) [self bytes];
   if( _dude_looks_like_a_number( (char *) s, len))
      return( YES);
      
   sentinel = &s[ len];
   while( s < sentinel)
   {
      if( ! isalnum( *s) && *s != '_')
         return( YES);
      ++s;
   }
   return( NO);
}

@end