uses c++23
[**example**](./main.cpp):
```cpp
#include "Random.hpp"
#include <iostream>
#include <vector>

int main() {
    Random rnd(12345); // Seed with 12345
    
    // Basic usage
    std::cout << "Int: " << rnd.nextInt() << '\n';
    std::cout << "Int (0-99): " << rnd.nextInt(100) << '\n';
    std::cout << "Long: " << rnd.nextLong() << '\n';
    std::cout << "Boolean: " << rnd.nextBoolean() << '\n';
    std::cout << "Float: " << rnd.nextFloat() << '\n';
    std::cout << "Double: " << rnd.nextDouble() << '\n';
    std::cout << "Gaussian: " << rnd.nextGaussian() << '\n';

    // C++23 style usage
    std::cout << "Random int: " << rnd() << '\n';
    std::cout << "Random float: " << rnd.nextReal<float>() << '\n';
    std::cout << "Random uint16_t: " << rnd.next<uint16_t>() << '\n';

    // STL compatibility
    std::vector<int> numbers(10);
    std::generate(numbers.begin(), numbers.end(), rnd);
    
    return 0;
}
```