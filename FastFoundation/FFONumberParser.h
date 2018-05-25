//
//  FFONumberParser.h
//  FastFoundation
//
//  Created by Michael Eisel on 5/25/18.
//  Copyright © 2018 Michael Eisel. All rights reserved.
//

static void FFOParseNumber(const char *string, FFOCallbacks *callbacks)
{
    uint32_t idx = 0;
    double d = 0.0;
    bool useNanOrInf = false;

    // Parse minus
    bool minus = NO;
    if (string[idx] == '-') {
        idx++;
        minus = YES;
    }

    // Parse int: zero / ( digit1-9 *DIGIT )
    unsigned i = 0;
    uint64_t i64 = 0;
    bool use64bit = false;
    int significandDigit = 0;
    if (unlikely(string[idx] == '0')) {
        i = 0;
        idx++;
        // todo: this seems wrong
    }
    else if (likely(string[idx] >= '1' && string[idx] <= '9')) {
        i = string[idx] - '0';

        if (minus)
            while (likely(string[idx] >= '0' && string[idx] <= '9')) {
                if (unlikely(i >= 214748364)) { // 2^31 = 2147483648
                    if (likely(i != 214748364 || string[idx] > '8')) {
                        i64 = i;
                        use64bit = true;
                        break;
                    }
                }
                i = i * 10 + string[idx++] - '0';
                significandDigit++;
            }
        else
            while (likely(string[idx] >= '0' && string[idx] <= '9')) {
                if (unlikely(i >= 429496729)) { // 2^32 - 1 = 4294967295
                    if (likely(i != 429496729 || string[idx] > '5')) {
                        i64 = i;
                        use64bit = true;
                        break;
                    }
                }
                i = i * 10 + string[idx++] - '0';
                significandDigit++;
            }
    }
    // Parse NaN or Infinity here
    else if (likely((string[idx] == 'I' || string[idx] == 'N'))) {
        if (FFOConsume(string, &idx, 'N')) {
            if (FFOConsume(string, &idx, 'a') && FFOConsume(string, &idx, 'N')) {
                d = NAN;
                useNanOrInf = true;
            }
        }
        else if (likely(FFOConsume(string, &idx, 'I'))) {
            if (FFOConsume(string, &idx, 'n') && FFOConsume(string, &idx, 'f')) {
                d = minus ? -INFINITY : INFINITY;
                useNanOrInf = true;

                if (unlikely(string[idx] == 'i' && !(FFOConsume(string, &idx, 'i') && FFOConsume(string, &idx, 'n')
                                                     && FFOConsume(string, &idx, 'i') && FFOConsume(string, &idx, 't') && FFOConsume(string, &idx, 'y')))) {
                    FFOParseError(0, idx);
                }
            }
        }

        if (unlikely(!useNanOrInf)) {
            FFOParseError(0, idx);
        }
    }
    else
        ;// FFOParseError(0, idx);

    // Parse 64bit int
    bool useDouble = false;
    if (use64bit) {
        if (minus)
            while (likely(string[idx] >= '0' && string[idx] <= '9')) {
                if (unlikely(i64 >= RAPIDJSON_UINT64_C2(0x0CCCCCCC, 0xCCCCCCCC))) // 2^63 = 9223372036854775808
                    if (likely(i64 != RAPIDJSON_UINT64_C2(0x0CCCCCCC, 0xCCCCCCCC) || string[idx] > '8')) {
                        d = (double)i64;
                        useDouble = true;
                        break;
                    }
                i64 = i64 * 10 + (unsigned)string[idx++] - '0';
                significandDigit++;
            }
        else
            while (likely(string[idx] >= '0' && string[idx] <= '9')) {
                if (unlikely(i64 >= RAPIDJSON_UINT64_C2(0x19999999, 0x99999999))) // 2^64 - 1 = 18446744073709551615
                    if (likely(i64 != RAPIDJSON_UINT64_C2(0x19999999, 0x99999999) || string[idx] > '5')) {
                        d = (double)i64;
                        useDouble = true;
                        break;
                    }
                i64 = i64 * 10 + (unsigned)(string[idx++] - '0');
                significandDigit++;
            }
    }

    // Force double for big integer
    if (useDouble) {
        while (likely(string[idx] >= '0' && string[idx] <= '9')) {
            if (unlikely(d >= 1.7976931348623157e307)) // DBL_MAX / 10.0
                FFOParseError(0, idx);
            d = d * 10 + (string[idx++] - '0');
        }
    }

    // Parse frac = decimal-point 1*DIGIT
    int expFrac = 0;
    // size_t decimalPosition;
    if (FFOConsume(string, &idx, '.')) {
        assert("not supported yet" && NO);
        // decimalPosition = s.Length(); // put this back

        if (unlikely(!(string[idx] >= '0' && string[idx] <= '9')))
            FFOParseError(0, idx);

        if (!useDouble) {
#if RAPIDJSON_64BIT
            // Use i64 to store significand in 64-bit architecture
            if (!use64bit)
                i64 = i;

            while (likely(string[idx] >= '0' && string[idx] <= '9')) {
                if (i64 > RAPIDJSON_UINT64_C2(0x1FFFFF, 0xFFFFFFFF)) // 2^53 - 1 for fast path
                    break;
                else {
                    i64 = i64 * 10 + static_cast<unsigned>(string[idx++] - '0');
                    --expFrac;
                    if (i64 != 0)
                        significandDigit++;
                }
            }

            d = static_cast<double>(i64);
#else
            // Use double to store significand in 32-bit architecture
            d = (double)(use64bit ? i64 : i);
#endif
            useDouble = true;
        }

        while (likely(string[idx] >= '0' && string[idx] <= '9')) {
            if (significandDigit < 17) {
                d = d * 10.0 + (string[idx++] - '0');
                --expFrac;
                if (likely(d > 0.0))
                    significandDigit++;
            }
            else
                string[idx++];
        }
    }
    else
        ;// decimalPosition = s.Length(); // decimal position at the end of integer.

    // Parse exp = e [ minus / plus ] 1*DIGIT
    int exp = 0;
    if (FFOConsume(string, &idx, 'e') || FFOConsume(string, &idx, 'E')) {
        if (!useDouble) {
            d = (double)(use64bit ? i64 : i);
            useDouble = true;
        }

        bool expMinus = false;
        if (FFOConsume(string, &idx, '+'))
            ;
        else if (FFOConsume(string, &idx, '-'))
            expMinus = true;

        if (likely(string[idx] >= '0' && string[idx] <= '9')) {
            exp = (int)(string[idx++] - '0');
            if (expMinus) {
                // (exp + expFrac) must not underflow int => we're detecting when -exp gets
                // dangerously close to INT_MIN (a pessimistic next digit 9 would push it into
                // underflow territory):
                //
                //        -(exp * 10 + 9) + expFrac >= INT_MIN
                //   <=>  exp <= (expFrac - INT_MIN - 9) / 10
                assert(expFrac <= 0);
                int maxExp = (expFrac + 2147483639) / 10;

                while (likely(string[idx] >= '0' && string[idx] <= '9')) {
                    exp = exp * 10 + (int)(string[idx++] - '0');
                    if (unlikely(exp > maxExp)) {
                        while (unlikely(string[idx] >= '0' && string[idx] <= '9'))  // Consume the rest of exponent
                            idx++;
                    }
                }
            }
            else {  // positive exp
                int maxExp = 308 - expFrac;
                while (likely(string[idx] >= '0' && string[idx] <= '9')) {
                    exp = exp * 10 + (int)(string[idx++] - '0');
                    if (unlikely(exp > maxExp))
                        FFOParseError(0, idx);
                }
            }
        }
        else
            FFOParseError(0, idx);

        if (expMinus)
            exp = -exp;
    }

    // Finish parsing, call event according to the type of number.
    bool cont = true;

    /*if (parseFlags & kParseNumbersAsStringsFlag) {
     if (parseFlags & kParseInsituFlag) {
     s.Pop();  // Pop stack no matter if it will be used or not.
     typename InputStream::Ch* head = is.PutBegin();
     const size_t length = s.Tell() - startOffset;
     RAPIDJSON_ASSERT(length <= 0xFFFFFFFF);
     // unable to insert the \0 character here, it will erase the comma after this number
     const typename TargetEncoding::Ch* const str = reinterpret_cast<typename TargetEncoding::Ch*>(head);
     cont = handler.RawNumber(str, SizeType(length), false);
     }
     else {
     SizeType numCharsToCopy = static_cast<SizeType>(s.Length());
     StringStream srcStream(s.Pop());
     StackStream<typename TargetEncoding::Ch> dstStream(stack_);
     while (numCharsToCopy--) {
     Transcoder<UTF8<>, TargetEncoding>::Transcode(srcStream, dstStream);
     }
     dstStream.Put('\0');
     const typename TargetEncoding::Ch* str = dstStream.Pop();
     const SizeType length = static_cast<SizeType>(dstStream.Length()) - 1;
     cont = handler.RawNumber(str, SizeType(length), true);
     }
     }
     else {*/
    // missing a pop here

    if (useDouble) {
        assert("not supported yet" && NO);
        /*int p = exp + expFrac;
         size_t length = s.Length();
         const char* decimal = s.Pop();  // Pop stack no matter if it will be used or not.
         if (parseFlags & kParseFullPrecisionFlag)
         d = internal::StrtodFullPrecision(d, p, decimal, length, decimalPosition, exp);
         else
         d = internal::StrtodNormalPrecision(d, p);

         cont = handler.Double(minus ? -d : d);*/
    }
    else if (useNanOrInf) {
        assert("not supported yet" && NO);
        // cont = handler.Double(d);
    }
    else {
        if (use64bit) {
            if (minus)
                callbacks->numberCallback((int64_t)(~i64 + 1));
            // cont = handler.Int64((int64_t)(~i64 + 1));
            else
                callbacks->numberCallback(i64);
            // cont = handler.Uint64(i64);
        }
        else {
            if (minus)
                callbacks->numberCallback((int32_t)(~i + 1));
            // cont = handler.Int((int32_t)(~i + 1));
            else
                callbacks->numberCallback(i);
            // cont = handler.Uint(i);
        }
    }
    // }
    if (unlikely(!cont))
        FFOParseError(0, idx);
}

