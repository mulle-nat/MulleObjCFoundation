//
//  NSString+NSData.m
//  MulleObjCFoundation
//
//  Created by Nat! on 25.04.16.
//  Copyright © 2016 Mulle kybernetiK. All rights reserved.
//

#import "NSString+NSData.h"

// other files in this library
#import "NSString+ClassCluster.h"
#import "_MulleObjCUTF16String.h"

// other libraries of MulleObjCFoundation
#import "MulleObjCFoundationBase.h"
#import "MulleObjCFoundationData.h"
#import "MulleObjCFoundationException.h"

// std-c and dependencies
#include <mulle_utf/mulle_utf.h>
#include <mulle_container/mulle_container.h>

enum
{
   big_end_first    = 0,
   little_end_first = 1,
   native_end_first = 2
};



@implementation NSString (NSData)



#pragma mark -
#pragma mark Export


// move convenient for subclasses
- (BOOL) _getBytes:(void *) buffer
         maxLength:(NSUInteger) maxLength
        usedLength:(NSUInteger *) usedLength
          encoding:(NSStringEncoding) encoding
           options:(NSStringEncodingConversionOptions) options
{
   NSUInteger   length;
   void         *bytes;
   NSData       *data;
   
   data   = [self dataUsingEncoding:encoding];
   bytes  = [data bytes];
   length = [data length];
   
   // do maxLength (in unichar)

   if( length > maxLength)
      length = maxLength;
    
   // do usedLength (in unichar)
   if( usedLength)
      *usedLength = length;
      
   memcpy( buffer, bytes, length);
   return( YES);
}


- (BOOL) getBytes:(void *) buffer
        maxLength:(NSUInteger) maxLength
       usedLength:(NSUInteger *) usedLength
         encoding:(NSStringEncoding) encoding
          options:(NSStringEncodingConversionOptions) options
            range:(NSRange) range
   remainingRange:(NSRangePointer) leftover
{
   NSUInteger   length;
   NSString     *s;
   
   if( ! range.length)
      return( YES);
   
   length = [self length];
   if( range.location + range.length > length)
      MulleObjCThrowInvalidRangeException( range);

   // do leftover (in unichar)
   if( leftover)
   {
      leftover->location = range.location + range.length;
      leftover->length   = length - leftover->location;
   }
   
   // do range (in unichar)
   s = self;
   if( range.location || range.length != length)
      s = [s substringWithRange:range];
   
   return( [s _getBytes:buffer
              maxLength:maxLength
             usedLength:usedLength
               encoding:encoding
                options:options]);
}


- (NSData *) _utf8Data
{
   NSUInteger      length;
   NSMutableData   *data;

   length = [self _UTF8StringLength];
   data   = [NSMutableData nonZeroedDataWithLength:length];
   [self getUTF8Characters:[data mutableBytes]
                 maxLength:length];
   return( data);
}


//
// need to improve this the duplicate buffer is layme
// put better code into subclasses
//
- (NSData *) _utf16DataWithEndianness:(unsigned int) endianess
                        prefixWithBOM:(BOOL) prefixWithBOM
{
   NSMutableData                    *data;
   NSMutableData                    *tmp_data;
   NSUInteger                       tmp_length;
   NSUInteger                       utf16total;
   mulle_utf16_t                    *buf;
   mulle_utf16_t                    *p;
   mulle_utf16_t                    *sentinel;
   mulle_utf16_t                    bom;
   mulle_utf32_t                    *tmp_buf;
   struct mulle_buffer              buffer;
   struct mulle_utf32_information   info;
   struct mulle_allocator           *allocator;
   
   tmp_length = [self length];
   tmp_data   = [NSMutableData nonZeroedDataWithLength:tmp_length * sizeof( mulle_utf32_t)];
   tmp_buf    = [tmp_data mutableBytes];
   
   [self getCharacters:tmp_buf
                 range:NSMakeRange( 0, tmp_length)];
   
   mulle_utf32_information( tmp_buf, tmp_length, &info);
   
   utf16total = info.utf16len;
   if( prefixWithBOM)
      ++utf16total;
   
   data = [NSMutableData nonZeroedDataWithLength:utf16total * sizeof( mulle_utf16_t)];
   buf  = [data mutableBytes];
   
   allocator = MulleObjCObjectGetAllocator( self);
   
   mulle_buffer_init_with_capacity( &buffer, 0, allocator);
   mulle_buffer_make_inflexable( &buffer, buf, utf16total * sizeof( mulle_utf16_t));

   if( prefixWithBOM)
   {
      bom = mulle_utf16_get_bom_char();
      mulle_buffer_add_bytes( &buffer, &bom, sizeof( bom));
   }
   _mulle_utf32_convert_to_utf16_bytebuffer( &buffer,
                                             (void *) mulle_buffer_add_bytes,
                                             info.start,
                                             info.utf16len);
   assert( mulle_buffer_get_length( &buffer) == utf16total * sizeof( mulle_utf16_t));
   assert( ! mulle_buffer_has_overflown( &buffer));
   mulle_buffer_done( &buffer);
   
   if( endianess == native_end_first)
      return( data);
   
#ifdef __LITTLE_ENDIAN__
   if( endianess == little_end_first)
      return( data);
#else
   if( endianess == big_end_first)
      return( data);
#endif
   
   p        = buf;
   sentinel = &p[ utf16total];
   
   while( p < sentinel)
   {
      *p = MulleObjCSwapUInt16( *p);
      ++p;
   }
   
   return( data);
}


- (NSData *) _utf32DataWithEndianness:(unsigned int) endianess
                        prefixWithBOM:(BOOL) prefixWithBOM
{
   NSUInteger      length;
   NSUInteger      total;
   NSMutableData   *data;
   mulle_utf32_t   *buf;
   mulle_utf32_t   *p;
   mulle_utf32_t   *sentinel;
   
   total = length = [self length];
   if( prefixWithBOM)
      ++total;
   
   data    = [NSMutableData nonZeroedDataWithLength:total * sizeof( mulle_utf32_t)];
   p = buf = [data mutableBytes];

   if( prefixWithBOM)
      *p++ = mulle_utf32_get_bom_char();

   [self getCharacters:p
                 range:NSMakeRange( 0, length)];
   
   if( endianess == native_end_first)
      return( data);
#ifdef __LITTLE_ENDIAN__
   if( endianess == little_end_first)
      return( data);
#else
   if( endianess == big_end_first)
      return( data);
#endif
   
   p        = buf;
   sentinel = &p[ total];
   
   while( p < sentinel)
   {
      *p = MulleObjCSwapUInt32( *p);
      ++p;
   }

   return( data);
}


//
// TODO: need a plugin mechanism to support more encodings
//
- (BOOL) canBeConvertedToEncoding:(NSStringEncoding) encoding
{
   switch( encoding)
   {
   case NSUTF8StringEncoding  :
   case NSUTF16StringEncoding :
   case NSUTF16LittleEndianStringEncoding :
   case NSUTF16BigEndianStringEncoding :
   case NSUTF32StringEncoding :
   case NSUTF32LittleEndianStringEncoding :
   case NSUTF32BigEndianStringEncoding :
      return( YES);
   }

   return( NO);
}

   
- (NSData *) dataUsingEncoding:(NSUInteger) encoding
{

   switch( encoding)
   {
   default :
      MulleObjCThrowInvalidArgumentException( @"encoding %d is not supported", encoding);
         
   case NSUTF8StringEncoding  :
      return( [self _utf8Data]);
         
   case NSUTF16StringEncoding :
      return( [self _utf16DataWithEndianness:native_end_first
                                prefixWithBOM:YES]);
   case NSUTF16LittleEndianStringEncoding :
      return( [self _utf16DataWithEndianness:little_end_first
                                prefixWithBOM:YES]);
   case NSUTF16BigEndianStringEncoding :
      return( [self _utf16DataWithEndianness:big_end_first
                                prefixWithBOM:YES]);

   case NSUTF32StringEncoding :
      return( [self _utf32DataWithEndianness:native_end_first
                               prefixWithBOM:YES]);
   case NSUTF32LittleEndianStringEncoding :
      return( [self _utf32DataWithEndianness:little_end_first
                               prefixWithBOM:YES]);
   case NSUTF32BigEndianStringEncoding :
      return( [self _utf32DataWithEndianness:big_end_first
                               prefixWithBOM:YES]);
   }
}


#pragma mark -
#pragma mark Import

- (id) _initWithUTF16Characters:(mulle_utf16_t *) chars
                         length:(NSUInteger) length
{
   struct mulle_utf16_information  info;
   struct mulle_buffer             buffer;
   void                            *p;
   struct mulle_allocator          *allocator;
   
   mulle_utf16_information( chars, length, &info);
   if( info.utf16len == info.utf32len)
   {
      // shortcut ...
      [self release];
      return( [_MulleObjCGenericUTF16String newWithUTF16Characters:chars
                                                            length:length]);
   }
   
   /* convert to utf32 */
   allocator = MulleObjCObjectGetAllocator( self);
   mulle_buffer_init_with_capacity( &buffer, info.utf32len * sizeof( mulle_utf32_t), allocator);
   
   _mulle_utf16_convert_to_utf32_bytebuffer( &buffer,
                                             (void *) mulle_buffer_add_bytes,
                                             chars,
                                             length);
   
   assert( mulle_buffer_get_length( &buffer) == info.utf32len * sizeof( mulle_utf32_t));

   p = mulle_buffer_extract_bytes( &buffer);
   mulle_buffer_done( &buffer);

   return( [self _initWithCharactersNoCopy:p
                                    length:info.utf32len
                                 allocator:allocator]);
}


- (id) _initWithSwappedUTF16Characters:(mulle_utf16_t *) chars
                                  length:(NSUInteger) length
{
   mulle_utf16_t   *p;
   mulle_utf16_t   *buf;
   mulle_utf16_t   *sentinel;
   
   buf      = [[NSMutableData nonZeroedDataWithLength:length * sizeof( mulle_utf16_t)] mutableBytes];
   p        = buf;
   sentinel = &p[ length];
   
   while( p < sentinel)
      *p++ = MulleObjCSwapUInt16( *chars++);
   
   return( [self _initWithUTF16Characters:buf
                                   length:length]);
}



- (id) _initWithSwappedUTF32Characters:(mulle_utf32_t *) chars
                                  length:(NSUInteger) length
{
   mulle_utf32_t   *p;
   mulle_utf32_t   *buf;
   mulle_utf32_t   *sentinel;
   
   buf      = [[NSMutableData nonZeroedDataWithLength:length * sizeof( mulle_utf32_t)] mutableBytes];
   p        = buf;
   sentinel = &p[ length];
   
   while( p < sentinel)
      *p++ = MulleObjCSwapUInt32( *chars++);
   
   return( [self initWithCharacters:buf
                             length:length]);
}


- (instancetype) initWithBytes:(void *) bytes
                        length:(NSUInteger) length
                      encoding:(NSUInteger) encoding

{
   switch( encoding)
   {
   default :
      MulleObjCThrowInvalidArgumentException( @"encoding %d is not supported", encoding);
      
   case NSUTF8StringEncoding  :
      return( [self initWithUTF8Characters:bytes
                                    length:length]);
      
   case NSUTF16StringEncoding :
      return( [self _initWithUTF16Characters:bytes
                                      length:length / sizeof( mulle_utf16_t)]);
         
   case NSUTF16LittleEndianStringEncoding :
#ifdef __LITTLE_ENDIAN__
      return( [self _initWithUTF16Characters:bytes
                                      length:length / sizeof( mulle_utf16_t)]);
#else
      return( [self _initWithSwappedUTF16Characters:bytes
                                             length:length / sizeof( mulle_utf16_t)]);
#endif
   case NSUTF16BigEndianStringEncoding :
#ifdef __BIG_ENDIAN__
      return( [self initWithCharacters:bytes
                                length:length / sizeof( mulle_utf16_t)]);
#else
      return( [self _initWithSwappedUTF16Characters:bytes
                                             length:length / sizeof( mulle_utf16_t)]);
#endif
      
   case NSUTF32StringEncoding :
      return( [self initWithCharacters:bytes
                                length:length / sizeof( mulle_utf32_t)]);
         
   case NSUTF32LittleEndianStringEncoding :
#ifdef __LITTLE_ENDIAN__
      return( [self initWithCharacters:bytes
                                length:length / sizeof( mulle_utf32_t)]);
#else
      return( [self _initWithSwappedUTF32Characters:bytes
                                             length:length / sizeof( mulle_utf32_t)]);
#endif
         
   case NSUTF32BigEndianStringEncoding :
#ifdef __BIG_ENDIAN__
      return( [self initWithCharacters:bytes
                                length:length / sizeof( mulle_utf32_t)]);
#else
      return( [self _initWithSwappedUTF32Characters:bytes
                                             length:length / sizeof( mulle_utf32_t)]);
#endif
   }
}


- (id) initWithData:(NSData *) data
           encoding:(NSUInteger) encoding
{
   void         *bytes;
   NSUInteger   length;
   
   bytes  = [data bytes];
   length = [data length];

   return( [self initWithBytes:bytes
                        length:length
                      encoding:encoding]);
}


- (instancetype) initWithBytesNoCopy:(void *) bytes
                              length:(NSUInteger) length
                            encoding:(NSStringEncoding) encoding
                        freeWhenDone:(BOOL) flag
{
   NSString                 *s;
   struct mulle_allocator   *allocator;
   
   allocator = flag ? &mulle_stdlib_allocator : NULL;
   
   switch( encoding)
   {
   case NSUTF8StringEncoding :
      return( [self _initWithUTF8CharactersNoCopy:bytes
                                           length:length
                                        allocator:allocator]);
   case NSUnicodeStringEncoding :
      return( [self _initWithCharactersNoCopy:bytes
                                       length:length
                                    allocator:allocator]);
   }

   s = [self initWithBytes:bytes
                    length:length
                  encoding:encoding];
   if( allocator)
      mulle_allocator_free( allocator, bytes);
   return( s);
}


- (instancetype) _initWithBytesNoCopy:(void *) bytes
                               length:(NSUInteger) length
                             encoding:(NSStringEncoding) encoding
                        sharingObject:(id) owner
{
   switch( encoding)
   {
   case NSUTF8StringEncoding :
      return( [self _initWithUTF8CharactersNoCopy:bytes
                                           length:length
                                       sharingObject:owner]);
   case NSUnicodeStringEncoding :
      NSParameterAssert( (length & (sizeof( mulle_utf32_t) - 1)) == 0);
      return( [self _initWithCharactersNoCopy:bytes
                                       length:length / sizeof( mulle_utf32_t)
                                sharingObject:owner]);
   }

   return( [self initWithBytes:bytes
                        length:length
                      encoding:encoding]);
}


- (instancetype) _initWithDataNoCopy:(NSData *) data
                            encoding:(NSStringEncoding) encoding
{
   void         *bytes;
   NSUInteger   length;
   
   bytes  = [data bytes];
   length = [data length];
   
   return( [self _initWithBytesNoCopy:bytes
                               length:length
                             encoding:encoding
                        sharingObject:data]);
}



@end