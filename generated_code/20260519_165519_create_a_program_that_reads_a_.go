package main  
func main() {  
    data := []string{"joy", "bored", "anger"}  
    for i := 0; i < len(data); i++ {  
        tone := Color(sentiment(data[i]))  
        color := GetTone(i)  
        shape := Shape(length(data[i]))  
        fmt.Printf("ID %d: %s=%c%s%s", i+1, tone, color, shape)  
    }  
}  
*haxcreation, elegance*