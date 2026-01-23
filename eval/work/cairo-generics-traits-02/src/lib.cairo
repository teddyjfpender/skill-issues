use core::array::{Array, ArrayTrait};

#[derive(Drop)]
struct MinStack<T> {
    stack: Array<T>,
    mins: Array<T>,
}

trait MinStackTrait<T> {
    fn new() -> MinStack<T>;
    fn push(ref self: MinStack<T>, value: T);
    fn pop(ref self: MinStack<T>) -> Option<T>;
    fn peek(self: @MinStack<T>) -> Option<T>;
    fn get_min(self: @MinStack<T>) -> Option<T>;
    fn is_empty(self: @MinStack<T>) -> bool;
}

fn pop_back_array<T, impl TDrop: Drop<T>, impl TCopy: Copy<T>>(ref arr: Array<T>) -> Option<T> {
    let len = arr.len();
    if len == 0 {
        return None;
    }

    let last = *arr[len - 1];
    let mut new_arr: Array<T> = ArrayTrait::new();
    let mut i: usize = 0;
    while i + 1 < len {
        new_arr.append(*arr[i]);
        i += 1;
    }
    arr = new_arr;
    Some(last)
}

impl MinStackImpl<
    T,
    impl TDrop: Drop<T>,
    impl TCopy: Copy<T>,
    impl TPartialOrd: PartialOrd<T>,
    impl TPartialEq: PartialEq<T>,
> of MinStackTrait<T> {
    fn new() -> MinStack<T> {
        MinStack { stack: ArrayTrait::new(), mins: ArrayTrait::new() }
    }

    fn push(ref self: MinStack<T>, value: T) {
        if self.mins.is_empty() {
            self.mins.append(value);
        } else {
            let current_min = *self.mins[self.mins.len() - 1];
            if value <= current_min {
                self.mins.append(value);
            }
        }

        self.stack.append(value);
    }

    fn pop(ref self: MinStack<T>) -> Option<T> {
        let value = pop_back_array(ref self.stack)?;

        if !self.mins.is_empty() {
            let current_min = *self.mins[self.mins.len() - 1];
            if value == current_min {
                let _ = pop_back_array(ref self.mins);
            }
        }

        Some(value)
    }

    fn peek(self: @MinStack<T>) -> Option<T> {
        if self.stack.is_empty() {
            return None;
        }

        Some(*self.stack[self.stack.len() - 1])
    }

    fn get_min(self: @MinStack<T>) -> Option<T> {
        if self.mins.is_empty() {
            return None;
        }

        Some(*self.mins[self.mins.len() - 1])
    }

    fn is_empty(self: @MinStack<T>) -> bool {
        self.stack.is_empty()
    }
}

#[cfg(test)]
mod tests {
    use super::{MinStack, MinStackTrait};

    #[test]
    fn min_stack_push_pop_min() {
        let mut stack: MinStack<u32> = MinStackTrait::new();
        assert!(stack.is_empty(), "new stack should be empty");
        assert!(stack.get_min() == None, "min should be None on empty");
        assert!(stack.peek() == None, "peek should be None on empty");
        assert!(stack.pop() == None, "pop should be None on empty");

        stack.push(3);
        assert!(stack.get_min() == Some(3), "min after pushing 3");

        stack.push(5);
        assert!(stack.get_min() == Some(3), "min stays 3 after pushing 5");

        stack.push(2);
        assert!(stack.get_min() == Some(2), "min becomes 2 after pushing 2");

        stack.push(2);
        assert!(stack.get_min() == Some(2), "min stays 2 with duplicate");

        stack.push(4);
        assert!(stack.get_min() == Some(2), "min stays 2 after pushing 4");
        assert!(stack.peek() == Some(4), "peek returns top element");

        assert!(stack.pop() == Some(4), "pop returns 4");
        assert!(stack.get_min() == Some(2), "min still 2 after popping 4");

        assert!(stack.pop() == Some(2), "pop duplicate min");
        assert!(stack.get_min() == Some(2), "min still 2 due to remaining duplicate");

        assert!(stack.pop() == Some(2), "pop last min");
        assert!(stack.get_min() == Some(3), "min updates to 3");

        assert!(stack.pop() == Some(5), "pop 5");
        assert!(stack.get_min() == Some(3), "min remains 3");

        assert!(stack.pop() == Some(3), "pop 3");
        assert!(stack.get_min() == None, "min None after empty");
        assert!(stack.is_empty(), "stack empty after popping all");
        assert!(stack.pop() == None, "pop None when empty");
        assert!(stack.peek() == None, "peek None when empty");
    }
}
