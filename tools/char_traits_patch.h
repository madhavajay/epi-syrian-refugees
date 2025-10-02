#ifndef GDSFMT_CHAR_TRAITS_PATCH_H
#define GDSFMT_CHAR_TRAITS_PATCH_H

#include <cstddef>
#include <cstdint>
#include <cstring>
#include <cwchar>
#include <ios>

#ifndef EOF
#define EOF (-1)
#endif

namespace std {

template <>
struct char_traits<unsigned short> {
    using char_type  = unsigned short;
    using int_type   = std::uint32_t;
    using off_type   = streamoff;
    using pos_type   = streampos;
    using state_type = mbstate_t;

    static void assign(char_type& r, const char_type& c) { r = c; }
    static constexpr bool eq(char_type a, char_type b) { return a == b; }
    static constexpr bool lt(char_type a, char_type b) { return a < b; }

    static int compare(const char_type* s1, const char_type* s2, size_t n) {
        for (size_t i = 0; i < n; ++i) {
            if (lt(s1[i], s2[i])) return -1;
            if (lt(s2[i], s1[i])) return 1;
        }
        return 0;
    }

    static size_t length(const char_type* s) {
        size_t i = 0;
        while (!eq(s[i], char_type())) ++i;
        return i;
    }

    static const char_type* find(const char_type* s, size_t n, const char_type& a) {
        for (size_t i = 0; i < n; ++i) {
            if (eq(s[i], a)) return s + i;
        }
        return nullptr;
    }

    static char_type* move(char_type* dest, const char_type* src, size_t n) {
        return static_cast<char_type*>(::memmove(dest, src, n * sizeof(char_type)));
    }

    static char_type* copy(char_type* dest, const char_type* src, size_t n) {
        return static_cast<char_type*>(::memcpy(dest, src, n * sizeof(char_type)));
    }

    static char_type* assign(char_type* dest, size_t n, char_type value) {
        for (size_t i = 0; i < n; ++i) dest[i] = value;
        return dest;
    }

    static constexpr int_type to_int_type(char_type c) { return static_cast<int_type>(c); }
    static constexpr char_type to_char_type(int_type c) { return static_cast<char_type>(c); }
    static constexpr bool eq_int_type(int_type c1, int_type c2) { return c1 == c2; }

    static constexpr int_type eof() { return static_cast<int_type>(EOF); }
    static constexpr int_type not_eof(int_type c) { return eq_int_type(c, eof()) ? 0 : c; }
};

template <>
struct char_traits<unsigned int> {
    using char_type  = unsigned int;
    using int_type   = std::uint32_t;
    using off_type   = streamoff;
    using pos_type   = streampos;
    using state_type = mbstate_t;

    static void assign(char_type& r, const char_type& c) { r = c; }
    static constexpr bool eq(char_type a, char_type b) { return a == b; }
    static constexpr bool lt(char_type a, char_type b) { return a < b; }

    static int compare(const char_type* s1, const char_type* s2, size_t n) {
        for (size_t i = 0; i < n; ++i) {
            if (lt(s1[i], s2[i])) return -1;
            if (lt(s2[i], s1[i])) return 1;
        }
        return 0;
    }

    static size_t length(const char_type* s) {
        size_t i = 0;
        while (!eq(s[i], char_type())) ++i;
        return i;
    }

    static const char_type* find(const char_type* s, size_t n, const char_type& a) {
        for (size_t i = 0; i < n; ++i) {
            if (eq(s[i], a)) return s + i;
        }
        return nullptr;
    }

    static char_type* move(char_type* dest, const char_type* src, size_t n) {
        return static_cast<char_type*>(::memmove(dest, src, n * sizeof(char_type)));
    }

    static char_type* copy(char_type* dest, const char_type* src, size_t n) {
        return static_cast<char_type*>(::memcpy(dest, src, n * sizeof(char_type)));
    }

    static char_type* assign(char_type* dest, size_t n, char_type value) {
        for (size_t i = 0; i < n; ++i) dest[i] = value;
        return dest;
    }

    static constexpr int_type to_int_type(char_type c) { return c; }
    static constexpr char_type to_char_type(int_type c) { return c; }
    static constexpr bool eq_int_type(int_type c1, int_type c2) { return c1 == c2; }

    static constexpr int_type eof() { return static_cast<int_type>(EOF); }
    static constexpr int_type not_eof(int_type c) { return eq_int_type(c, eof()) ? 0 : c; }
};

} // namespace std

#endif // GDSFMT_CHAR_TRAITS_PATCH_H
