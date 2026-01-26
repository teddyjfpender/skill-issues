use cairo_trapping_rain_water_01::*;

#[cfg(test)]
mod tests {
    use super::*;
    
    mod edge_cases {
        use super::*;
        
        #[test]
        fn test_empty_array_all_implementations() {
            let input = array![];
            assert!(SolutionImpl::solve(@input) == 0);
            assert!(trap_brute_force(@input) == 0);
            assert!(trap_dp(@input) == 0);
            assert!(trap(@input) == 0);
        }
        
        #[test]
        fn test_single_element_all_implementations() {
            let input = array![5];
            assert!(SolutionImpl::solve(@input) == 0);
            assert!(trap_brute_force(@input) == 0);
            assert!(trap_dp(@input) == 0);
            assert!(trap(@input) == 0);
        }
        
        #[test]
        fn test_two_elements_all_implementations() {
            let input = array![3, 5];
            assert!(SolutionImpl::solve(@input) == 0);
            assert!(trap_brute_force(@input) == 0);
            assert!(trap_dp(@input) == 0);
            assert!(trap(@input) == 0);
        }
    }
    
    mod no_water_scenarios {
        use super::*;
        
        #[test]
        fn test_flat_array_all_implementations() {
            let input = array![3, 3, 3, 3];
            assert!(SolutionImpl::solve(@input) == 0);
            assert!(trap_brute_force(@input) == 0);
            assert!(trap_dp(@input) == 0);
            assert!(trap(@input) == 0);
        }
        
        #[test]
        fn test_ascending_all_implementations() {
            let input = array![1, 2, 3, 4, 5];
            assert!(SolutionImpl::solve(@input) == 0);
            assert!(trap_brute_force(@input) == 0);
            assert!(trap_dp(@input) == 0);
            assert!(trap(@input) == 0);
        }
        
        #[test]
        fn test_descending_all_implementations() {
            let input = array![5, 4, 3, 2, 1];
            assert!(SolutionImpl::solve(@input) == 0);
            assert!(trap_brute_force(@input) == 0);
            assert!(trap_dp(@input) == 0);
            assert!(trap(@input) == 0);
        }
    }
    
    mod water_scenarios {
        use super::*;
        
        #[test]
        fn test_simple_v_shape_all_implementations() {
            let input = array![5, 0, 5];
            assert!(SolutionImpl::solve(@input) == 5);
            assert!(trap_brute_force(@input) == 5);
            assert!(trap_dp(@input) == 5);
            assert!(trap(@input) == 5);
        }
        
        #[test]
        fn test_example_1_all_implementations() {
            let input = array![0, 1, 0, 2, 1, 0, 1, 3, 2, 1, 2, 1];
            let expected = 6;
            assert!(SolutionImpl::solve(@input) == expected);
            assert!(trap_brute_force(@input) == expected);
            assert!(trap_dp(@input) == expected);
            assert!(trap(@input) == expected);
        }
        
        #[test]
        fn test_example_2_all_implementations() {
            let input = array![4, 2, 0, 3, 2, 5];
            let expected = 9;
            assert!(SolutionImpl::solve(@input) == expected);
            assert!(trap_brute_force(@input) == expected);
            assert!(trap_dp(@input) == expected);
            assert!(trap(@input) == expected);
        }
    }
    
    mod trait_tests {
        use super::*;
        
        #[test]
        fn test_rain_water_trait_solve() {
            assert!(RainWaterImpl::solve(@array![0, 1, 0, 2, 1, 0, 1, 3, 2, 1, 2, 1]) == 6);
        }
        
        #[test]
        fn test_rain_water_trait_brute_force() {
            assert!(RainWaterImpl::solve_brute_force(@array![4, 2, 0, 3, 2, 5]) == 9);
        }
        
        #[test]
        fn test_rain_water_trait_dp() {
            assert!(RainWaterImpl::solve_dp(@array![3, 0, 2]) == 2);
        }
        
        #[test]
        fn test_rain_water_trait_two_pointers() {
            assert!(RainWaterImpl::solve_two_pointers(@array![5, 0, 5]) == 5);
        }
    }
    
    mod equivalence {
        use super::*;
        
        #[test]
        fn test_all_implementations_equivalence() {
            let test_cases = array![
                array![0, 1, 0, 2, 1, 0, 1, 3, 2, 1, 2, 1],
                array![4, 2, 0, 3, 2, 5],
                array![5, 0, 5],
                array![3, 0, 2],
                array![1, 2, 3, 4, 5],
                array![5, 4, 3, 2, 1],
                array![3, 3, 3, 3],
                array![]
            ];
            
            let mut i: u32 = 0;
            while i < 8 {
                let (bf_result, dp_result, optimal_result) = if i == 0 { 
                    (trap_brute_force(@array![0, 1, 0, 2, 1, 0, 1, 3, 2, 1, 2, 1]),
                     trap_dp(@array![0, 1, 0, 2, 1, 0, 1, 3, 2, 1, 2, 1]),
                     trap(@array![0, 1, 0, 2, 1, 0, 1, 3, 2, 1, 2, 1]))
                } else if i == 1 { 
                    (trap_brute_force(@array![4, 2, 0, 3, 2, 5]),
                     trap_dp(@array![4, 2, 0, 3, 2, 5]),
                     trap(@array![4, 2, 0, 3, 2, 5]))
                } else if i == 2 { 
                    (trap_brute_force(@array![5, 0, 5]),
                     trap_dp(@array![5, 0, 5]),
                     trap(@array![5, 0, 5]))
                } else if i == 3 { 
                    (trap_brute_force(@array![3, 0, 2]),
                     trap_dp(@array![3, 0, 2]),
                     trap(@array![3, 0, 2]))
                } else if i == 4 { 
                    (trap_brute_force(@array![1, 2, 3, 4, 5]),
                     trap_dp(@array![1, 2, 3, 4, 5]),
                     trap(@array![1, 2, 3, 4, 5]))
                } else if i == 5 { 
                    (trap_brute_force(@array![5, 4, 3, 2, 1]),
                     trap_dp(@array![5, 4, 3, 2, 1]),
                     trap(@array![5, 4, 3, 2, 1]))
                } else if i == 6 { 
                    (trap_brute_force(@array![3, 3, 3, 3]),
                     trap_dp(@array![3, 3, 3, 3]),
                     trap(@array![3, 3, 3, 3]))
                } else { 
                    (trap_brute_force(@array![]),
                     trap_dp(@array![]),
                     trap(@array![]))
                };
                
                assert!(bf_result == dp_result);
                assert!(dp_result == optimal_result);
                i += 1;
            };
        }
    }
}
