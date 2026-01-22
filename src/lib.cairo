struct Pair<T> {
    first: T,
    second: T,
}

trait Swap<T> {
    fn swap(self: Pair<T>) -> Pair<T>;
}

impl PairSwap<T> of Swap<T> {
    fn swap(self: Pair<T>) -> Pair<T> {
        Pair { first: self.second, second: self.first }
    }
}

fn demo() -> Pair<u32> {
    let pair = Pair { first: 1_u32, second: 2_u32 };
    pair.swap()
}

#[cfg(test)]
mod tests {
    use super::{Pair, Swap};

    #[test]
    fn swap_pair_u32() {
        let pair = Pair { first: 10_u32, second: 20_u32 };
        let swapped = pair.swap();
        assert(swapped.first == 20_u32, 'swap first');
        assert(swapped.second == 10_u32, 'swap second');
    }
}
