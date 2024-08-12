fn main() {
    let vec = vec![1, 2, 3, 4, 5];
    let double_sum: i32 = vec.iter().map(|x| x * 2).sum();

    println!("{}", double_sum);
}
