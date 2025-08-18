// Randomjava.hpp
#pragma once

#include <cstdint>
#include <limits>
#include <cmath>
#include <bit>
#include <concepts>
#include <optional>

class Random {
private:
    uint64_t seed;

    static constexpr uint64_t multiplier = 0x5DEECE66DLL;
    static constexpr uint64_t addend = 0xBLL;
    static constexpr uint64_t mask = (1LL << 48) - 1;

    int next(int bits) {
        seed = (seed * multiplier + addend) & mask;
        return static_cast<int>(seed >> (48 - bits));
    }

public:
    // Constructors
    Random() : Random(0) {}
    
    explicit Random(uint64_t seed) {
        setSeed(seed);
    }

    // Seed management
    void setSeed(uint64_t seed) {
        this->seed = (seed ^ multiplier) & mask;
    }

    // Random number generation
    int nextInt() {
        return next(32);
    }

    template<std::integral T>
    T nextInt(T bound) requires (std::is_unsigned_v<T> || bound > 0) {
        if (bound == 0) {
            return 0;
        }

        if (std::has_single_bit(bound)) { // Power of 2
            return static_cast<T>((bound * static_cast<uint64_t>(next(31))) >> 31);
        }

        int bits, val;
        do {
            bits = next(31);
            val = bits % bound;
        } while (bits - val + (bound - 1) < 0);
        
        return static_cast<T>(val);
    }

    int64_t nextLong() {
        return (static_cast<int64_t>(next(32)) << 32) + next(32);
    }

    bool nextBoolean() {
        return next(1) != 0;
    }

    float nextFloat() {
        return next(24) / static_cast<float>(1 << 24);
    }

    double nextDouble() {
        return ((static_cast<int64_t>(next(26)) << 27) + next(27)) / static_cast<double>(1LL << 53);
    }

    double nextGaussian() {
        // Using std::optional for thread safety (each call gets its own gaussian)
        static thread_local std::optional<double> nextGaussian;

        if (nextGaussian) {
            double result = *nextGaussian;
            nextGaussian.reset();
            return result;
        }

        double v1, v2, s;
        do {
            v1 = 2 * nextDouble() - 1;
            v2 = 2 * nextDouble() - 1;
            s = v1 * v1 + v2 * v2;
        } while (s >= 1 || s == 0);

        double multiplier = std::sqrt(-2 * std::log(s)/s);
        nextGaussian = v2 * multiplier;
        return v1 * multiplier;
    }

    // C++23 additions
    auto operator()() {
        return nextInt();
    }

    template<std::floating_point T>
    T nextReal() {
        if constexpr (std::is_same_v<T, float>) {
            return nextFloat();
        } else {
            return nextDouble();
        }
    }

    template<std::integral T>
    T next() {
        if constexpr (sizeof(T) <= 4) {
            return static_cast<T>(nextInt());
        } else {
            return static_cast<T>(nextLong());
        }
    }
};

