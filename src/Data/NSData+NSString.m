//
//  NSData+NSString.m
//  MulleObjCFoundation
//
//  Created by Nat! on 03.05.16.
//  Copyright © 2016 Mulle kybernetiK. All rights reserved.
//

#import "NSData.h"

// other files in this library

// other libraries of MulleObjCFoundation
#import "MulleObjCFoundationString.h"

// std-c and dependencies
#include <ctype.h>


@implementation NSData (NSString)

static inline unsigned int   hex( unsigned int c)
{
   assert( c >= 0 && c <= 0xf);
   return( c >= 0xa ? c + 'a' - 0xa : c + '0');
}

#define WORD_SIZE   4

- (NSString *) description
{
   NSUInteger               full_lines;
   NSUInteger               i;
   NSUInteger               j;
   NSUInteger               length;
   NSUInteger               lines;
   NSUInteger               remainder;
   mulle_utf8_t             *s;
   struct mulle_allocator   *allocator;
   struct mulle_buffer      buffer;
   unsigned char            *bytes;
   unsigned int             value;
   
   length = [self length];
   if( ! length)
      return( @"<>");
   
   bytes     = [self bytes];
   allocator = MulleObjCObjectGetAllocator( self);
   
   mulle_buffer_init( &buffer, allocator);
   
   mulle_buffer_add_string( &buffer, "<");
   
   lines      = (length + WORD_SIZE - 1) / WORD_SIZE;
   full_lines = length / WORD_SIZE;
   
   for( i = 0; i < full_lines; i++)
   {
      s = mulle_buffer_advance( &buffer, 2 * WORD_SIZE);
      for( j = 0;  j < WORD_SIZE; j++)
      {
         value = *bytes++;
         
         *s++ = (mulle_utf8_t) hex( value >> 4);
         *s++ = (mulle_utf8_t) hex( value & 0xF);
      }
      mulle_buffer_add_byte( &buffer, ' ');
   }
   
   if( i < lines)
   {
      remainder = length - (full_lines * WORD_SIZE);
      s = mulle_buffer_advance( &buffer, 2 * remainder);
      for( j = 0;  j < remainder; j++)
      {
         value = *bytes++;
         
         *s++ = (mulle_utf8_t) hex( value >> 4);
         *s++ = (mulle_utf8_t) hex( value & 0xF);
      }
   }
   else
      mulle_buffer_remove_last_byte( &buffer);

   mulle_buffer_add_byte( &buffer, '>');
   mulle_buffer_add_byte( &buffer, 0);
   
   length = mulle_buffer_get_length( &buffer);
   s      = mulle_buffer_extract_bytes( &buffer);
   mulle_buffer_done( &buffer);
   
   return( [NSString _stringWithUTF8CharactersNoCopy:s
                                              length:length
                                           allocator:allocator]);
}


- (NSString *) debugDescription
{
   NSUInteger               length;
   mulle_utf8_t             *s;
   struct mulle_allocator   *allocator;
   struct mulle_buffer      buffer;
   unsigned char            *bytes;

   length = [self length];
   if( ! length)
      return( @"<>");
   
   bytes     = [self bytes];
   allocator = MulleObjCObjectGetAllocator( self);
   
   mulle_buffer_init( &buffer, allocator);
   
   mulle_buffer_dump_hex( &buffer, bytes, length, 0, 0);
   mulle_buffer_add_byte( &buffer, 0);

   length = mulle_buffer_get_length( &buffer);
   s      = mulle_buffer_extract_bytes( &buffer);

   mulle_buffer_done( &buffer);
   
   return( [NSString _stringWithUTF8CharactersNoCopy:s
                                              length:length
                                           allocator:allocator]);
}


@end