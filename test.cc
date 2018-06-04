
#include <algorithm>
#include <experimental/filesystem>
#include <iostream>
#include <optional>

int main(int argc, char** argv)
{
    std::optional opt = std::make_optional<std::string>("optional string");

    std::cout << "Hello, Clang!" << std::endl;
    std::cout << "have_fs=" << std::experimental::filesystem::exists("/etc") << std::endl;
    std::cout << "optional=" << *opt << std::endl;
    return 1;
}
