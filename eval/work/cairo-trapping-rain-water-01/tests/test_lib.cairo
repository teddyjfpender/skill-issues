use cairo_trapping_rain_water_01::*;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_example_1() {
        let input = array![0, 1, 0, 2, 1, 0, 1, 3, 2, 1, 2, 1];
        assert!(RainWaterImpl::brute_force(@input) == 6);
        assert!(RainWaterImpl::dynamic_programming(@input) == 6);
        assert!(RainWaterImpl::two_pointers(@input) == 6);
        assert!(RainWaterImpl::solve(@input) == 6);
        assert!(SolutionImpl::solve(@input) == 6);
    }

    #[test]
    fn test_example_2() {
        let input = array![4, 2, 0, 3, 2, 5];
        assert!(RainWaterImpl::brute_force(@input) == 9);
        assert!(RainWaterImpl::dynamic_programming(@input) == 9);
        assert!(RainWaterImpl::two_pointers(@input) == 9);
        assert!(RainWaterImpl::solve(@input) == 9);
        assert!(SolutionImpl::solve(@input) == 9);
    }

    #[test]
    fn test_empty_array() {
        let input = array![];
        assert!(RainWaterImpl::brute_force(@input) == 0);
        assert!(RainWaterImpl::dynamic_programming(@input) == 0);
        assert!(RainWaterImpl::two_pointers(@input) == 0);
        assert!(RainWaterImpl::solve(@input) == 0);
        assert!(SolutionImpl::solve(@input) == 0);
    }

    #[test]
    fn test_single_element() {
        let input = array![5];
        assert!(RainWaterImpl::brute_force(@input) == 0);
        assert!(RainWaterImpl::dynamic_programming(@input) == 0);
        assert!(RainWaterImpl::two_pointers(@input) == 0);
        assert!(RainWaterImpl::solve(@input) == 0);
        assert!(SolutionImpl::solve(@input) == 0);
    }

    #[test]
    fn test_two_elements() {
        let input = array![3, 5];
        assert!(RainWaterImpl::brute_force(@input) == 0);
        assert!(RainWaterImpl::dynamic_programming(@input) == 0);
        assert!(RainWaterImpl::two_pointers(@input) == 0);
        assert!(RainWaterImpl::solve(@input) == 0);
        assert!(SolutionImpl::solve(@input) == 0);
    }

    #[test]
    fn test_flat_array() {
        let input = array![3, 3, 3, 3];
        assert!(RainWaterImpl::brute_force(@input) == 0);
        assert!(RainWaterImpl::dynamic_programming(@input) == 0);
        assert!(RainWaterImpl::two_pointers(@input) == 0);
        assert!(RainWaterImpl::solve(@input) == 0);
        assert!(SolutionImpl::solve(@input) == 0);
    }

    #[test]
    fn test_descending() {
        let input = array![5, 4, 3, 2, 1];
        assert!(RainWaterImpl::brute_force(@input) == 0);
        assert!(RainWaterImpl::dynamic_programming(@input) == 0);
        assert!(RainWaterImpl::two_pointers(@input) == 0);
        assert!(RainWaterImpl::solve(@input) == 0);
        assert!(SolutionImpl::solve(@input) == 0);
    }

    #[test]
    fn test_ascending() {
        let input = array![1, 2, 3, 4, 5];
        assert!(RainWaterImpl::brute_force(@input) == 0);
        assert!(RainWaterImpl::dynamic_programming(@input) == 0);
        assert!(RainWaterImpl::two_pointers(@input) == 0);
        assert!(RainWaterImpl::solve(@input) == 0);
        assert!(SolutionImpl::solve(@input) == 0);
    }

    #[test]
    fn test_v_shape() {
        let input = array![5, 0, 5];
        assert!(RainWaterImpl::brute_force(@input) == 5);
        assert!(RainWaterImpl::dynamic_programming(@input) == 5);
        assert!(RainWaterImpl::two_pointers(@input) == 5);
        assert!(RainWaterImpl::solve(@input) == 5);
        assert!(SolutionImpl::solve(@input) == 5);
    }
}

#[test]
fn test_helper_functions() {
    assert!(max_u32(5, 3) == 5);
    assert!(max_u32(2, 7) == 7);
    assert!(min_u32(5, 3) == 3);
    assert!(min_u32(2, 7) == 2);
}

#[test]
fn test_solution_placeholder() {
    assert!(SolutionImpl::solve(@array![]) == 0);
}

#[test]
fn test_brute_force_empty() {
    assert!(trap_brute_force(@array![]) == 0);
}

#[test]
fn test_brute_force_single() {
    assert!(trap_brute_force(@array![5]) == 0);
}

#[test]
fn test_brute_force_no_water() {
    assert!(trap_brute_force(@array![1, 2, 3, 4, 5]) == 0);
}

#[test]
fn test_brute_force_simple() {
    assert!(trap_brute_force(@array![3, 0, 2, 0, 4]) == 7);
}

#[test]
fn test_brute_force_complex() {
    assert!(trap_brute_force(@array![0, 1, 0, 2, 1, 0, 1, 3, 2, 1, 2, 1]) == 6);
}

#[test]
fn test_dp_empty() {
    assert!(trap_dp(@array![]) == 0);
}

#[test]
fn test_dp_single() {
    assert!(trap_dp(@array![5]) == 0);
}

#[test]
fn test_dp_no_water() {
    assert!(trap_dp(@array![1, 2, 3, 4, 5]) == 0);
}

#[test]
fn test_dp_simple() {
    assert!(trap_dp(@array![3, 0, 2, 0, 4]) == 7);
}

#[test]
fn test_dp_complex() {
    assert!(trap_dp(@array![0, 1, 0, 2, 1, 0, 1, 3, 2, 1, 2, 1]) == 6);
}

#[test]
fn test_trap_empty() {
    assert!(trap(@array![]) == 0);
}

#[test]
fn test_trap_single() {
    assert!(trap(@array![5]) == 0);
}

#[test]
fn test_trap_no_water() {
    assert!(trap(@array![1, 2, 3, 4, 5]) == 0);
}

#[test]
fn test_trap_simple() {
    assert!(trap(@array![3, 0, 2, 0, 4]) == 7);
}

#[test]
fn test_trap_complex() {
    assert!(trap(@array![0, 1, 0, 2, 1, 0, 1, 3, 2, 1, 2, 1]) == 6);
}

#[test]
fn test_rain_water_trait_brute_force() {
    assert!(RainWaterImpl::brute_force(@array![3, 0, 2, 0, 4]) == 7);
    assert!(RainWaterImpl::brute_force(@array![0, 1, 0, 2, 1, 0, 1, 3, 2, 1, 2, 1]) == 6);
}

#[test]
fn test_rain_water_trait_dp() {
    assert!(RainWaterImpl::dynamic_programming(@array![3, 0, 2, 0, 4]) == 7);
    assert!(RainWaterImpl::dynamic_programming(@array![0, 1, 0, 2, 1, 0, 1, 3, 2, 1, 2, 1]) == 6);
}

#[test]
fn test_rain_water_trait_two_pointers() {
    assert!(RainWaterImpl::two_pointers(@array![3, 0, 2, 0, 4]) == 7);
    assert!(RainWaterImpl::two_pointers(@array![0, 1, 0, 2, 1, 0, 1, 3, 2, 1, 2, 1]) == 6);
}

#[test]
fn test_rain_water_trait_solve() {
    assert!(RainWaterImpl::solve(@array![3, 0, 2, 0, 4]) == 7);
    assert!(RainWaterImpl::solve(@array![0, 1, 0, 2, 1, 0, 1, 3, 2, 1, 2, 1]) == 6);
    assert!(RainWaterImpl::solve(@array![]) == 0);
}
