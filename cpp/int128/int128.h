#ifndef INT128_H
#define INT128_H

#include <iostream>
#include <string>
#include <stdexcept>
#include <type_traits>
#include <cmath>
#include <climits>

class int128_t {
private:
    __int128 value;

public:
    // 构造函数
    int128_t() : value(0) {}
    int128_t(__int128 v) : value(v) {}
    
    // 从各种整数类型转换
    template<typename T, typename = std::enable_if_t<std::is_integral_v<T>>>
    int128_t(T v) : value(static_cast<__int128>(v)) {}
    
    // 从字符串构造
    explicit int128_t(const std::string& str, int base = 10) {
        value = 0;
        from_string(str, base);
    }

    // 拷贝构造函数
    int128_t(const int128_t& other) : value(other.value) {}

    // 赋值运算符
    int128_t& operator=(const int128_t& other) {
        if (this != &other) {
            value = other.value;
        }
        return *this;
    }

    // 转换为各种类型
    explicit operator bool() const { return value != 0; }
    explicit operator char() const { return static_cast<char>(value); }
    explicit operator short() const { return static_cast<short>(value); }
    explicit operator int() const { return static_cast<int>(value); }
    explicit operator long() const { return static_cast<long>(value); }
    explicit operator long long() const { return static_cast<long long>(value); }
    explicit operator unsigned char() const { return static_cast<unsigned char>(value); }
    explicit operator unsigned short() const { return static_cast<unsigned short>(value); }
    explicit operator unsigned int() const { return static_cast<unsigned int>(value); }
    explicit operator unsigned long() const { return static_cast<unsigned long>(value); }
    explicit operator unsigned long long() const { return static_cast<unsigned long long>(value); }
    explicit operator float() const { return static_cast<float>(value); }
    explicit operator double() const { return static_cast<double>(value); }
    explicit operator long double() const { return static_cast<long double>(value); }

    // 算术运算符
    int128_t operator+(const int128_t& other) const { return value + other.value; }
    int128_t operator-(const int128_t& other) const { return value - other.value; }
    int128_t operator*(const int128_t& other) const { return value * other.value; }
    int128_t operator/(const int128_t& other) const {
        if (other.value == 0) throw std::runtime_error("Division by zero");
        return value / other.value;
    }
    int128_t operator%(const int128_t& other) const {
        if (other.value == 0) throw std::runtime_error("Division by zero");
        return value % other.value;
    }

    // 一元运算符
    int128_t operator+() const { return *this; }
    int128_t operator-() const { return -value; }

    // 前置/后置递增递减
    int128_t& operator++() { ++value; return *this; }
    int128_t operator++(int) { int128_t tmp(*this); ++value; return tmp; }
    int128_t& operator--() { --value; return *this; }
    int128_t operator--(int) { int128_t tmp(*this); --value; return tmp; }

    // 复合赋值运算符
    int128_t& operator+=(const int128_t& other) { value += other.value; return *this; }
    int128_t& operator-=(const int128_t& other) { value -= other.value; return *this; }
    int128_t& operator*=(const int128_t& other) { value *= other.value; return *this; }
    int128_t& operator/=(const int128_t& other) {
        if (other.value == 0) throw std::runtime_error("Division by zero");
        value /= other.value;
        return *this;
    }
    int128_t& operator%=(const int128_t& other) {
        if (other.value == 0) throw std::runtime_error("Division by zero");
        value %= other.value;
        return *this;
    }

    // 位运算符
    int128_t operator&(const int128_t& other) const { return value & other.value; }
    int128_t operator|(const int128_t& other) const { return value | other.value; }
    int128_t operator^(const int128_t& other) const { return value ^ other.value; }
    int128_t operator~() const { return ~value; }

    int128_t operator<<(int n) const {
        if (n < 0 || n >= 128) throw std::out_of_range("Shift amount out of range");
        return value << n;
    }

    int128_t operator>>(int n) const {
        if (n < 0 || n >= 128) throw std::out_of_range("Shift amount out of range");
        return value >> n;
    }

    // 位复合赋值运算符
    int128_t& operator&=(const int128_t& other) { value &= other.value; return *this; }
    int128_t& operator|=(const int128_t& other) { value |= other.value; return *this; }
    int128_t& operator^=(const int128_t& other) { value ^= other.value; return *this; }
    int128_t& operator<<=(int n) {
        if (n < 0 || n >= 128) throw std::out_of_range("Shift amount out of range");
        value <<= n;
        return *this;
    }
    int128_t& operator>>=(int n) {
        if (n < 0 || n >= 128) throw std::out_of_range("Shift amount out of range");
        value >>= n;
        return *this;
    }

    // 比较运算符
    bool operator==(const int128_t& other) const { return value == other.value; }
    bool operator!=(const int128_t& other) const { return value != other.value; }
    bool operator<(const int128_t& other) const { return value < other.value; }
    bool operator<=(const int128_t& other) const { return value <= other.value; }
    bool operator>(const int128_t& other) const { return value > other.value; }
    bool operator>=(const int128_t& other) const { return value >= other.value; }

    // 数学函数
    static int128_t abs(const int128_t& x) {
        return x < 0 ? -x : x;
    }

    int128_t abs() const {
        return abs(*this);
    }

    // 转换为字符串
    std::string to_string(int base = 10) const {
        if (base < 2 || base > 36) {
            throw std::invalid_argument("Base must be between 2 and 36");
        }

        if (value == 0) return "0";

        __int128 n = value;
        bool negative = n < 0;
        if (negative) n = -n;

        std::string result;
        const char* digits = "0123456789abcdefghijklmnopqrstuvwxyz";

        while (n > 0) {
            result = digits[n % base] + result;
            n /= base;
        }

        if (negative) result = "-" + result;
        return result;
    }

    // 从字符串解析
    void from_string(const std::string& str, int base = 10) {
        if (base < 2 || base > 36) {
            throw std::invalid_argument("Base must be between 2 and 36");
        }

        value = 0;
        size_t i = 0;
        bool negative = false;

        // 处理符号
        if (str[i] == '-') {
            negative = true;
            i++;
        } else if (str[i] == '+') {
            i++;
        }

        // 处理基数前缀
        if (base == 16 && str.size() - i >= 2 && str[i] == '0' && (str[i+1] == 'x' || str[i+1] == 'X')) {
            i += 2;
        } else if (base == 8 && str.size() - i >= 1 && str[i] == '0') {
            i += 1;
        } else if (base == 2 && str.size() - i >= 2 && str[i] == '0' && (str[i+1] == 'b' || str[i+1] == 'B')) {
            i += 2;
        }

        // 转换数字
        for (; i < str.size(); i++) {
            char c = str[i];
            int digit;
            
            if (c >= '0' && c <= '9') digit = c - '0';
            else if (c >= 'a' && c <= 'z') digit = c - 'a' + 10;
            else if (c >= 'A' && c <= 'Z') digit = c - 'A' + 10;
            else throw std::invalid_argument("Invalid character in string");

            if (digit >= base) throw std::invalid_argument("Digit exceeds base");

            value = value * base + digit;
        }

        if (negative) value = -value;
    }

    // 获取底层值
    __int128 get_value() const { return value; }

    // 友元函数
    friend std::ostream& operator<<(std::ostream& os, const int128_t& num);
    friend std::istream& operator>>(std::istream& is, int128_t& num);
};

// 流操作符
std::ostream& operator<<(std::ostream& os, const int128_t& num) {
    os << num.to_string();
    return os;
}

std::istream& operator>>(std::istream& is, int128_t& num) {
    std::string str;
    is >> str;
    num.from_string(str);
    return is;
}

// 数学函数
inline int128_t abs(const int128_t& x) {
    return int128_t::abs(x);
}

// 类型别名
using uint128_t = unsigned __int128;

#endif // INT128_H
