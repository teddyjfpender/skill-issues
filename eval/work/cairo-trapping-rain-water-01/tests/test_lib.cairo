use cairo_trapping_rain_water_01::*;

#[test]
fn test_basic() {
    assert!(SolutionImpl::solve(@array![0, 1, 0, 2, 1, 0, 1, 3, 2, 1, 2, 1]) == 6);
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
fn test_brute_force_two_elements() {
    assert!(trap_brute_force(@array![3, 7]) == 0);
}

#[test]
fn test_brute_force_no_water() {
    assert!(trap_brute_force(@array![1, 2, 3, 4, 5]) == 0);
}

#[test]
fn test_brute_force_simple() {
    assert!(trap_brute_force(@array![3, 0, 2]) == 2);
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
fn test_dp_two_elements() {
    assert!(trap_dp(@array![3, 7]) == 0);
}

#[test]
fn test_dp_no_water() {
    assert!(trap_dp(@array![1, 2, 3, 4, 5]) == 0);
}

#[test]
fn test_dp_simple() {
    assert!(trap_dp(@array![3, 0, 2]) == 2);
}

#[test]
fn test_dp_basic() {
    assert!(trap_dp(@array![0, 1, 0, 2, 1, 0, 1, 3, 2, 1, 2, 1]) == 6);
}

#[test]
fn test_optimal_empty() {
    assert!(trap(@array![]) == 0);
}

#[test]
fn test_optimal_single() {
    assert!(trap(@array![5]) == 0);
}

#[test]
fn test_optimal_two_elements() {
    assert!(trap(@array![3, 7]) == 0);
}

#[test]
fn test_optimal_no_water() {
    assert!(trap(@array![1, 2, 3, 4, 5]) == 0);
}

#[test]
fn test_optimal_simple() {
    assert!(trap(@array![3, 0, 2]) == 2);
}

#[test]
fn test_optimal_basic() {
    assert!(trap(@array![0, 1, 0, 2, 1, 0, 1, 3, 2, 1, 2, 1]) == 6);
}

#[test]
fn test_rain_water_trait_solve() {
    assert!(RainWaterImpl::solve(@array![0, 1, 0, 2, 1, 0, 1, 3, 2, 1, 2, 1]) == 6);
}

#[test]
fn test_rain_water_trait_brute_force() {
    assert!(RainWaterImpl::brute_force(@array![3, 0, 2]) == 2);
}

#[test]
fn test_rain_water_trait_dp() {
    assert!(RainWaterImpl::dynamic_programming(@array![3, 0, 2]) == 2);
}

#[test]
fn test_rain_water_trait_optimal() {
    assert!(RainWaterImpl::optimal(@array![3, 0, 2]) == 2);
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_example_1() {
        let input = array![0, 1, 0, 2, 1, 0, 1, 3, 2, 1, 2, 1];
        assert!(trap_brute_force(@input) == 6);
        assert!(trap_dp(@input) == 6);
        assert!(trap(@input) == 6);
    }
    
    #[test]
    fn test_example_2() {
        let input = array![4, 2, 0, 3, 2, 5];
        assert!(trap_brute_force(@input) == 9);
        assert!(trap_dp(@input) == 9);
        assert!(trap(@input) == 9);
    }
    
    #[test]
    fn test_empty_array() {
        let input = array![];
        assert!(trap_brute_force(@input) == 0);
        assert!(trap_dp(@input) == 0);
        assert!(trap(@input) == 0);
    }
    
    #[test]
    fn test_single_element() {
        let input = array![5];
        assert!(trap_brute_force(@input) == 0);
        assert!(trap_dp(@input) == 0);
        assert!(trap(@input) == 0);
    }
    
    #[test]
    fn test_two_elements() {
        let input = array![3, 7];
        assert!(trap_brute_force(@input) == 0);
        assert!(trap_dp(@input) == 0);
        assert!(trap(@input) == 0);
    }
    
    #[test]
    fn test_flat_array() {
        let input = array![3, 3, 3, 3];
        assert!(trap_brute_force(@input) == 0);
        assert!(trap_dp(@input) == 0);
        assert!(trap(@input) == 0);
    }
    
    #[test]
    fn test_descending() {
        let input = array![5, 4, 3, 2, 1];
        assert!(trap_brute_force(@input) == 0);
        assert!(trap_dp(@input) == 0);
        assert!(trap(@input) == 0);
    }
    
    #[test]
    fn test_ascending() {
        let input = array![1, 2, 3, 4, 5];
        assert!(trap_brute_force(@input) == 0);
        assert!(trap_dp(@input) == 0);
        assert!(trap(@input) == 0);
    }
    
    #[test]
    fn test_v_shape() {
        let input = array![5, 0, 5];
        assert!(trap_brute_force(@input) == 5);
        assert!(trap_dp(@input) == 5);
        assert!(trap(@input) == 5);
    }
}
